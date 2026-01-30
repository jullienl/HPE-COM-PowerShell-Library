#------------------- FUNCTIONS FOR HPE GreenLake SERVICES -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1
using module .\Utilities.psm1 # for Set-HPECOMJobTemplatesVariable

# Public Functions
Function Get-HPEGLService {
    <#
    .SYNOPSIS
    Retrieve the list of services and instances.

    .DESCRIPTION
    This Cmdlet returns a collection of services that are available for provisioning or that are already provisioned.    

    .PARAMETER Name 
    An optional parameter to display a service by name.

    .PARAMETER Region 
    An optional parameter to display a service instance in a region. You can use 'Get-HPEGLRegion' to see all available regions.

    .PARAMETER ShowProvisioned 
    An optional parameter to display the list of provisioned services.

    .PARAMETER ShowUnprovisioned 
    An optional parameter to display the list of available services that can be provisioned.

    .PARAMETER ShowAssignedDevices 
    An optional parameter to display the list of devices assigned to a particular service instance.

    .PARAMETER WhatIf 
    Displays the raw REST API call that would be made to GLP instead of sending the request. Useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLService

    Returns all services, both those available for provisioning and those already provisioned.

    .EXAMPLE
    Get-HPEGLService -Name 'Compute Ops Management'

    Returns all Compute Ops Management service instances.

    .EXAMPLE
    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned

    Returns all Compute Ops Management service instances that are provisioned. 

    .EXAMPLE
    Get-HPEGLService -Name 'Compute Ops Management' -Region EU

    Returns all Compute Ops Management service instances that are provisioned in Europe. 

    .EXAMPLE
    Get-HPEGLService -ShowUnprovisioned 

    Returns all services available for provisioning in different regions.

    .EXAMPLE
    Get-HPEGLService -ShowUnprovisioned -Region 'eu-central'

    Returns all services available for provisioning in the Central Europe region.
    

#>

    [CmdletBinding(DefaultParameterSetName = 'Provisioned')]
    Param( 
        [Parameter (ParameterSetName = 'Provisioned')]
        [Parameter (ParameterSetName = 'Available')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedDevices')]
        # [ValidateSet( 'Compute Ops Management', 'Data Services', 'Aruba Central', 'HPE GreenLake' )]
        [String]$Name,            
 
        [Parameter (ParameterSetName = 'Provisioned')]
        [Parameter (ParameterSetName = 'Available')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedDevices')]
        [String]$Region,
    
        [Parameter (ParameterSetName = 'Provisioned')]
        [Switch]$ShowProvisioned,

        [Parameter (ParameterSetName = 'Available')]
        [Switch]$ShowUnprovisioned,

        [Parameter (ParameterSetName = 'AssignedDevices')]
        [Switch]$ShowAssignedDevices,

        [Switch]$WhatIf

    ) 
    
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-ApplicationsProvisionsUri

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose


        try {
            "[{0}] Sending GET request to: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
            [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            "[{0}] Response received: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Collection | Out-String) | Write-Verbose

        }
        catch {
   
            $PSCmdlet.ThrowTerminatingError($_)
       
        }
       
        
        if ($ShowAssignedDevices) {

            try {
                $AppRegionfound = Get-HPEGLService -Name $Name -Region $Region
            }
            catch {
       
                $PSCmdlet.ThrowTerminatingError($_)
           
            }
          
            if ($AppRegionfound) {

                $ServiceInstanceId = $AppRegionfound.application_id

                try {
                    [array]$Collection = Get-HPEGLdevice | Where-Object { $_.application.id -eq $ServiceInstanceId }
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "Device"
                    $ReturnData = $ReturnData | Sort-Object serialNumber, region
                    return $ReturnData 
                }
                catch {
           
                    $PSCmdlet.ThrowTerminatingError($_)
               
                }

            }
        }

        
        if ($Null -ne $Collection.provisions) {

            $CollectionList = $Collection.provisions 

            # Remove Company_name property as it is causing some issue with Get-HPEGLAuditLog when Get-HPEGLServie is used as a pipeline input. Company_name holds no important information but just "Hewlett Packard Enterprise"
            $CollectionList = $CollectionList | Select-Object -Property * -ExcludeProperty company_name
            
            if ($ShowProvisioned) {
                $CollectionList = $CollectionList | Where-Object { $_.provision_status -eq "PROVISIONED" }
            }

            if ($ShowUnprovisioned) {
                $CollectionList = $CollectionList | Where-Object { $_.provision_status -ne "PROVISIONED" }
            }
            
            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "Service"   


            if ($Name -and -not $Region) {
                $ReturnData = $ReturnData | Where-Object { $_.name -eq $name } | Sort-Object region, region
            }
            elseif ($Name -and $Region) {
                $ReturnData = $ReturnData | Where-Object { $_.name -eq $name -and $_.region -eq $Region } | Sort-Object name, region
            }
            elseif (-not $Name -and $Region) {
                $ReturnData = $ReturnData | Where-Object { $_.region -eq $Region } | Sort-Object name, region
            }
            else {
                $ReturnData = $ReturnData | Sort-Object name, region
            }     

            return $ReturnData 

        }
        else {

            return 
            
        }
    }
}

Function Get-HPEGLServiceScopeFilter {
    <#
    .SYNOPSIS
    Retrieve scope filters for service instances.

    .DESCRIPTION
    This Cmdlet returns the scope filters (formerly known as Resource Restriction Policies) that are available in service instances.
    Scope filters enable scope-based access control (SBAC) in HPE GreenLake Platform, allowing you to restrict user access to specific resources within a service.
    
    When called without parameters, it retrieves scope filters from all provisioned services across all regions.
    When called with ServiceName and ServiceRegion, it retrieves scope filters for that specific service instance.

    .PARAMETER ServiceName
    Name of the service to retrieve scope filters from (can be retrieved using 'Get-HPEGLService'). 
    If not specified, scope filters from all provisioned services will be returned.
    Must be used together with ServiceRegion.

    .PARAMETER ServiceRegion 
    Name of the region of the service (can be retrieved using 'Get-HPEGLService').
    If not specified, scope filters from all provisioned services will be returned.
    Must be used together with ServiceName.

    .PARAMETER FilterName
    Optional parameter to display a specific scope filter by name.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLServiceScopeFilter

    Returns all scope filters from all provisioned services across all regions.

    .EXAMPLE
    Get-HPEGLServiceScopeFilter -ServiceName 'Compute Ops Management' -ServiceRegion "eu-central"

    Returns all scope filters for the Compute Ops Management service in the Central European region.

    .EXAMPLE
    Get-HPEGLServiceScopeFilter -ServiceName 'Compute Ops Management' -ServiceRegion "us-west" -FilterName "Production_Servers"

    Returns the 'Production_Servers' scope filter for the 'Compute Ops Management' service in the US western region.

    .EXAMPLE
    Get-HPEGLServiceScopeFilter -ServiceName 'Compute Ops Management' -ServiceRegion "eu-central" | Select-Object Name, Description, Service, Region

    Returns all scope filters for COM in eu-central with selected properties displayed.

   #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter(ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            try {
                # Check if session exists
                if (-not $Global:HPEGreenLakeSession) { return @() }
                
                $Services = Get-HPEGLService -ShowProvisioned -Verbose:$false -ErrorAction SilentlyContinue | 
                    Select-Object -ExpandProperty Name -Unique
                
                if ($Services) {
                    $Services | Where-Object { $_ -like "*$wordToComplete*" } | ForEach-Object {
                        if ($_ -match '\s') { "'$_'" } else { $_ }
                    }
                }
            }
            catch { @() }
        })]
        [String]$ServiceName,   
        
        [Parameter(ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            try {
                # Check if session exists
                if (-not $Global:HPEGreenLakeSession) { return @() }
                
                # If ServiceName is provided, only show regions where that service is provisioned
                if ($fakeBoundParameters.ServiceName) {
                    $Regions = Get-HPEGLService -ShowProvisioned -Verbose:$false -ErrorAction SilentlyContinue | 
                        Where-Object { $_.Name -eq $fakeBoundParameters.ServiceName } | 
                        Select-Object -ExpandProperty region -Unique
                }
                else {
                    $Regions = Get-HPEGLService -ShowProvisioned -Verbose:$false -ErrorAction SilentlyContinue | 
                        Select-Object -ExpandProperty region -Unique
                }
                
                if ($Regions) {
                    $Regions | Where-Object { $_ -like "*$wordToComplete*" } | Sort-Object
                }
            }
            catch { @() }
        })]
        [String]$ServiceRegion,

        [Parameter(ValueFromPipelineByPropertyName)]
        [String]$FilterName,

        [Switch]$WhatIf

    ) 
    
    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $_Services = Get-HPEGLService -ShowProvisioned 
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # If no ServiceName/ServiceRegion specified, get scope filters from all provisioned services
        if (-not $ServiceName -and -not $ServiceRegion) {
            "[{0}] No service specified. Retrieving scope filters from all provisioned services" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            $AllScopeFilters = @()
            foreach ($Service in $_Services) {
                "[{0}] Processing service '{1}' in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Service.Name, $Service.region | Write-Verbose
                
                # Recursively call this function with specific service and region
                $ServiceFilters = Get-HPEGLServiceScopeFilter -ServiceName $Service.Name -ServiceRegion $Service.region -FilterName $FilterName -WhatIf:$WhatIf
                
                if ($ServiceFilters) {
                    $AllScopeFilters += $ServiceFilters
                }
            }
            
            return $AllScopeFilters
        }

        # Validate that both ServiceName and ServiceRegion are provided together
        if (($ServiceName -and -not $ServiceRegion) -or (-not $ServiceName -and $ServiceRegion)) {
            throw "Both ServiceName and ServiceRegion must be specified together."
        }

        "[{0}] Retrieving scope filters for service '{1}' in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRegion | Write-Verbose
            
        # PRE-VALIDATION: Check if service is provisioned in the specified region
        $_Service = $_Services | Where-Object { $_.Name -eq $ServiceName -and $_.region -eq $ServiceRegion }
                
        if (-not $_Service) {
            # Service not provisioned - validation failure
            if ($WhatIf) {
                Write-Warning "Service '$ServiceName' is not provisioned in the '$ServiceRegion' region. Cannot display API request."
                return
            }
            else {
                # Get-* cmdlets return nothing silently for "not found" (no error)
                "[{0}] Service '{1}' is not provisioned in the '{2}' region - returning nothing" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRegion | Write-Verbose
                return
            }
        }

        # Validation passed - proceed with API call
        # Get workspace ID from global session
        $WorkspaceId = $Global:HPEGreenLakeSession.WorkspaceId
        
        # Determine service provider slug based on service name
        $ServiceSlug = switch ($ServiceName) {
            'Compute Ops Management' { 'compute-ops-mgmt' }
            'Backup and Recovery' { 'data-services-cloud-console' }
            'Private Cloud Business Edition' { 'private-cloud-business-edition' }
            default { 
                # For services without explicit mapping, try converting name to slug format
                $ServiceName.ToLower() -replace '\s+', '-'
            }
        }

        # Build GRN pattern for the filter query
        $GrnPattern = "grn:glp/workspaces/$WorkspaceId/regions/$ServiceRegion/providers/$ServiceSlug/filter/*"
        
        # Build URI with query parameters
        $EncodedGrn = [System.Web.HttpUtility]::UrlEncode($GrnPattern)
        $Uri = "{0}/internal-authorization/v2alpha1/resources?grn={1}&limit=200&offset=0" -f (Get-HPEGLAPIOrgbaseURL), $EncodedGrn
       
        try {
            $Response = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
        }
        catch {
            # If this is a 400/403/404 error, the service likely doesn't support scope filters or access is denied
            $StatusCode = $_.Exception.Response.StatusCode.value__
            if ($StatusCode -in 400, 403, 404) {
                if ($WhatIf) {
                    Write-Warning "Service '$ServiceName' in region '$ServiceRegion' does not support scope filters or access denied. Cannot display API request."
                    return
                }
                else {
                    "[{0}] Service '{1}' in region '{2}' does not support scope filters or access denied (HTTP {3})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRegion, $StatusCode | Write-Verbose
                    return
                }
            }
            else {
                # For other errors, throw
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }

        # Invoke-HPEGLWebRequest already returns the items array for paginated responses
        $Collection = $Response

        if ($Null -ne $Collection -and $Collection.Count -gt 0) {
           
            if ($FilterName) {
                $Collection = $Collection | Where-Object displayName -eq $FilterName
            }
            else {
                # Exclude default "AllScopes" filters that grant access to everything
                $Collection = $Collection | Where-Object displayName -ne 'AllScopes'
            }

            # Transform the response to match the legacy format
            $ReturnData = @()
            
            # Cache for COM filters by region to avoid multiple calls for same region
            $ComFiltersCache = @{}
            
            foreach ($Item in $Collection) {
                
                # Extract region from GRN
                if ($Item.grn -match 'regions/([^/]+)/providers/[^/]+/filter/') {
                    $ExtractedRegion = $Matches[1]
                }
                else {
                    $ExtractedRegion = $ServiceRegion
                }

                # Try to get additional details from COM filter if available
                # Only retrieve for Compute Ops Management service
                $Description = $null
                $FilterExpression = $null
                
                if ($ServiceName -eq 'Compute Ops Management' -and $Item.displayName) {
                    # Check if we already have filters for this region
                    if (-not $ComFiltersCache.ContainsKey($ExtractedRegion)) {
                        try {
                            "[{0}] Retrieving COM filter details for region '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ExtractedRegion | Write-Verbose
                            $ComFiltersCache[$ExtractedRegion] = Get-HPECOMFilter -Region $ExtractedRegion -Verbose:$false
                        }
                        catch {
                            "[{0}] Unable to retrieve COM filter details for region '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ExtractedRegion, $_.Exception.Message | Write-Verbose
                            $ComFiltersCache[$ExtractedRegion] = $null
                        }
                    }
                    
                    # Look up the matching filter
                    if ($ComFiltersCache[$ExtractedRegion]) {
                        $MatchingComFilter = $ComFiltersCache[$ExtractedRegion] | Where-Object { $_.Name -eq $Item.displayName }
                        if ($MatchingComFilter) {
                            $Description = $MatchingComFilter.Description
                            $FilterExpression = $MatchingComFilter.Filter
                        }
                    }
                }
                
                $FilterObject = [PSCustomObject]@{
                    Name        = $Item.displayName
                    Description = $Description
                    Service     = $ServiceName
                    Region      = $ExtractedRegion
                    Filter      = $FilterExpression
                    Id          = $Item.id
                    Type        = $Item.type
                    GRN         = $Item.grn
                }

                $ReturnData += $FilterObject
            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "Service.ScopeFilter"         
            $ReturnData = $ReturnData | Sort-Object Name

            return $ReturnData
        }     
       
        else {
            return 
        }
    }
}

Function Get-HPEGLServiceResourceRestrictionPolicy {
    <#
    .SYNOPSIS
    [DEPRECATED] Retrieve resource restriction policies. Use Get-HPEGLServiceScopeFilter instead.

    .DESCRIPTION
    This Cmdlet returns the resource restriction policies that are available in a service instance.
    
    DEPRECATION NOTICE: This cmdlet is deprecated and maintained for backward compatibility only.
    HPE GreenLake has transitioned from "Resource Restriction Policies" to "Scope-Based Access Control" with scope filters.
    Please use 'Get-HPEGLServiceScopeFilter' for new implementations.

    .PARAMETER ServiceName
    Parameter to display resource restriction policy for a service name (can be retrieved using 'Get-HPEGLService').

    .PARAMETER ServiceRegion 
    Name of the region of the service (can be retrieved using Get-HPEGLService).

    .PARAMETER PolicyName
    Name of a policy to display.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLServiceResourceRestrictionPolicy -ServiceName 'Compute Ops Management' -ServiceRegion "eu-central"

    Returns all resource restriction policies for the Compute Ops Management service in the Central European region.

    .EXAMPLE
    Get-HPEGLServiceResourceRestrictionPolicy -ServiceName 'Compute Ops Management' -ServiceRegion "us-west" -PolicyName ESXi_Houston

    Returns the 'ESXi_Houston' resource restriction policy for the 'Compute Ops Management' service in the US western region.

   #>
    [CmdletBinding(DefaultParameterSetName = 'WithoutService')]
    Param( 

        [Parameter (ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = 'WithoutService')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = 'WithService')]
        [String]$ServiceName,   
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = 'WithService')]
        [String]$ServiceRegion,

        [String]$PolicyName,

        [Switch]$WhatIf

    ) 
    
    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose


    }

    Process {

        # DEPRECATION WARNING
        Write-Warning "[DEPRECATED] This function is deprecated. HPE has replaced Resource Restriction Policies (RRP) with Scope-Based Access Control (SBAC). Please use 'Get-HPEGLServiceScopeFilter' instead. This function will be removed in a future release."

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

         try {
                $_Services = Get-HPEGLService -ShowProvisioned 
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

        if ($ServiceName) {
            
            "[{0}] Retrieving legacy resource restriction policy (RRP) filters for service '{1}' in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRegion | Write-Verbose
                
            $_Service = $_Services | Where-Object { $_.Name -eq $ServiceName -and $_.region -eq $ServiceRegion }
                    
            if ($_Service) {
                $ServiceID = $_Service.application_id
                $Uri = (Get-AuthorizationResourceRestrictionsUri) + "?application_id=" + $ServiceID #+ "&include_predefined_filters_and_scope_resource_instances=true"
            }
            else {
                $ErrorMessage = "Service '{0}' is not provisioned in the '{1}' region!" -f $ServiceName, $ServiceRegion
                Write-warning $ErrorMessage
                return
            }
        }
        else {
            "[{0}] Retrieving all legacy resource restriction policy (RRP) filters" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            $Uri = (Get-AuthorizationResourceRestrictionsUri) 
        }
       
        try {
            [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Get policies
        $Collection = $Collection.policies



        if ($Null -ne $Collection) {
           
            if ($ServiceName) {
                $Collection = $Collection | Where-Object {$_.application_id -eq $ServiceID }
            }

            if ($PolicyName) {
                $Collection = $Collection | Where-Object name -eq $PolicyName
            }

            # Add region to object
            Foreach ($Item in $Collection) {
                $ServiceInstanceRegion = ($_Services | Where-Object { $_.application_id -eq $Item.application_id }).region
                $Item | Add-Member -type NoteProperty -name region -value $ServiceInstanceRegion

                $ResourceRestrictionId = $Item.resource_restriction_policy_id

                $uri = (Get-ResourceRestrictionPolicyUri) + $ResourceRestrictionId 
                try {
                    [array]$ScopeResources = Invoke-HPEGLWebRequest -Method Get -Uri $uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                if ($ScopeResources.scope_resource_instances -and $ScopeResources.scope_resource_instances.Count -gt 0) {
                 
                    $Item | Add-Member -type NoteProperty -name scope_resources -value $ScopeResources.scope_resource_instances -Force
                }

            }

            # $FilterList = @()
            
            # if ($Collection.slug -eq "HPECC") {
               
            #     $ServiceInstanceId = $_Service.application_instance_id
            #     $ServiceCustomerId = $_Service.application_customer_id
            #     $Slug = $Collection.scope_resources.slug

            #     $Uri = (Get-ApplicationInstancesUri) + "/" + $ServiceInstanceId + "/scope_resource_instances?limit=200&offset=0&application_cid=" + $ServiceCustomerId + "&scope_resource=$slug"
            
            #     try {
            #         [array]$FilterCollection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
              
            #     }
            #     catch {

            #         $PSCmdlet.ThrowTerminatingError($_)
   
            #     }

            #     # $FilterCollection | Out-String | Write-Verbose

            #     foreach ($Filter in $FilterCollection.scope_resource_instances) {
                    
            #         "[{0}] Filter '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $filter.name | Write-Verbose

            #         $ReturnData = $FilterCollection | Select-Object  `
            #         @{N = "filter_name"; E = { $Filter.name } }, `
            #         @{N = "application_name"; E = { $ServiceName } }, `
            #         @{N = "region"; E = { $Collection.region } }, `
            #         @{N = "slug"; E = { $Filter.slug } }, `
            #         @{N = "scope_type_name"; E = { $_.scope_resource_instances.name } }, `
            #             # @{N = "description"; E = { $_.scope_resource_instances.description } }, `
            #         @{N = "application_customer_id"; E = { $_.application_customer_id } }, `
            #         @{N = "application_instance_id"; E = { $_.application_instance_id } }, `
            #         @{N = "application_id"; E = { $_.application_id } }

            #         $FilterList += $ReturnData | Sort-Object -Property filter_name
            #     }

            # } 

            # elseif ($Collection.scope_resources) {
               
            #     foreach ($Filter in $Collection.scope_resources) {
                    
            #         "[{0}] Filter '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $filter.name | Write-Verbose

            #         $ReturnData = $Collection | Select-Object  `
            #         @{N = "filter_name"; E = { $Filter.name } }, `
            #         @{N = "application_name"; E = { $ServiceName } }, `
            #         @{N = "region"; E = { $_.region } }, `
            #         @{N = "slug"; E = { $Filter.slug } }, `
            #         @{N = "scope_type_name"; E = { $_.scope_resources.name } }, `
            #             # @{N = "description"; E = { $_.scope_resources.description } }, `
            #         @{N = "application_customer_id"; E = { $_.application_customer_id } }, `
            #         @{N = "application_instance_id"; E = { $_.application_instance_id } }, `
            #         @{N = "application_id"; E = { $_.application_id } }

            #         $FilterList += $ReturnData | Sort-Object -Property filter_name
            #     }
            # }
            # elseif ($Collection.predefined_filters) {      
                    
            #     foreach ($Filter in $Collection.predefined_filters) {
                        
            #         "[{0}] Predefined filter '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Filter.name | Write-Verbose

            #         $ReturnData = $Collection | Select-Object  `
            #         @{N = "filter_name"; E = { $Filter.name } }, `
            #         @{N = "application_name"; E = { $ServiceName } }, `
            #         @{N = "region"; E = { $_.region } }, `
            #         @{N = "slug"; E = { $Filter.slug } }, `
            #         @{N = "scope_type_name"; E = { $Filter.name } }, `
            #             # @{N = "description"; E = { $Filter.description } }, `
            #         @{N = "application_customer_id"; E = { $_.application_customer_id } }, `
            #         @{N = "application_instance_id"; E = { $_.application_instance_id } }, `
            #         @{N = "application_id"; E = { $_.application_id } }

            #         $FilterList += $ReturnData | Sort-Object -Property filter_name
            #     }
            # } 

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "Service.ResourceRestrictionPolicy"         
            $ReturnData = $ReturnData | sort-object name

            return $ReturnData
        }     
       
        else {
            return 
        }
    }
}

Function New-HPEGLService {
    <#
    .SYNOPSIS
    Deploy a new service in a specified region.

    .DESCRIPTION
    This Cmdlet can be used to deploy a service in a new region within HPE GreenLake. By deploying a service, you enable its functionalities and resources in the selected region.
    
    If the service being deployed is a Compute Ops Management instance, the cmdlet automatically generates temporary API client credentials for the proper functioning of this library with COM.

    .PARAMETER Name 
    The name of the available service to deploy. This value can be retrieved from 'Get-HPEGLService -ShowUnprovisioned'.

    .PARAMETER Region 
    The name of the region where the service will be deployed. This value can be retrieved from 'Get-HPEGLService -ShowUnprovisioned'.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    New-HPEGLService -Name "Compute Ops Management" -Region "eu-central"
    $Global:HPEGreenLakeSession.username | Add-HPEGLRoleToUser -RoleName 'Compute Ops Management administrator'

    This example deploys the "Compute Ops Management" service in the "eu-central" region.
    It also assigns the Compute Ops Management administrator role to the currently connected user, as specified in the tracking object generated by Connect-HPEGL.

    .EXAMPLE
    Get-HPEGLService -ShowUnprovisioned -Name "Aruba Central" -Region "us-west" | New-HPEGLService

    Retrieves the "Aruba Central" service available in the "us-west" region and deploys it.

    .EXAMPLE
    Get-HPEGLService -ShowUnprovisioned -Name "Compute Ops Management" | New-HPEGLService

    Retrieves all unprovisioned instances of the "Compute Ops Management" service across all regions and deploys them in their respective regions.

    .INPUTS
    System.Collections.ArrayList
        A list of services obtained from 'Get-HPEGLService -ShowUnprovisioned'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the service attempted to be deployed.
        * Region - The name of the region where the service was deployed.
        * Status - The status of the deployment attempt (Failed for HTTP error return; Complete if deployment is successful; Warning if no action is needed).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.

    #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('applicationname')]
        [String]$Name,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('ccs_region')]
        [String]$Region,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-ApplicationProvisioningUri  
        $AddServiceStatus = [System.Collections.ArrayList]::new()


    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }      

        try {
            $Appfound = Get-HPEGLService -Name $Name -Region $Region 
        }
        catch {    
            $PSCmdlet.ThrowTerminatingError($_)
        }
        
        if (-not $Appfound) {
            # Must return a message if Service is not found 
            "[{0}] Service '{1}' is not available in '{2}' region for provisioning!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Service '{0}' is not available in '{1}' region for provisioning!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Service is not available in this region for provisioning!"
            }
        }
        elseif ($Appfound.provision_status -eq "PROVISIONED") {
            # Must return a message if Service is already provisioned 
            "[{0}] Service '{1}' is already provisioned in '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Service '{0}': Resource is already provisioned in '{1}' region! No action needed." -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Service is already provisioned in this region! No action needed."
            }
        }
        else {
       
            $ServiceID = $Appfound.application_id


            # Build payload
            $payload = ConvertTo-Json @{
                region         = $Region
                application_id = $ServiceID 
                action         = "PROVISION"
                
            }
      

            # Deploy the service in a region. 
            try {
                Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | Out-Null
            }
            catch {
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Service cannot be deployed!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }  
                
            if (-not $WhatIf) {

                "[{0}] Service '{1}' successfully deployed in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                    
                $maxRetries = 10
                $retryCount = 0
                do {
                    # Waiting for the service to be provisioned
                    "[{0}] Waiting for the service '{1}' to be provisioned in '{2}' region... (Attempt {3}/{4})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region, ($retryCount + 1), $maxRetries | Write-Verbose
                    try {
                        $ServiceProvision = Get-HPEGLService -Name $name -Region $Region
                        $provision_status = $ServiceProvision.provision_status
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                    Start-Sleep 2
                    $retryCount++
                    if ($retryCount -ge $maxRetries) {
                        throw "Provisioning timed out after $maxRetries attempts for service '$name' in region '$Region'."
                    }
                } until ($provision_status -eq "PROVISIONED")

                if ($provision_status -eq "PROVISIONED") {
                    
                    "[{0}] Service '{1}' is provisioned in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Service successfully deployed in '$Region' region"

                    # If the provisioned service is Compute Ops Management, get the login URL and add the region to the global variable for the argument completer for the Region parameter of *HPECOM* cmdlets
                    if ($Name -eq "Compute Ops Management") {

                        # Getting login url for the provisioned service
                        $url = (Get-ApplicationsLoginUrlUri) + $ServiceProvision.application_instance_id

                        "[{0}] Retrieving login URL for the Compute Ops Management service in '{1}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                        "[{0}] About to run a GET {1} " -f $MyInvocation.InvocationName.ToString().ToUpper(), $url | Write-Verbose

                        try {
                            $LoginURLResponse = Invoke-RestMethod -Method Get -Uri $url -WebSession $Global:HPEGreenLakeSession.WorkspaceSession #-AllowInsecureRedirect
                        }
                        catch {
                            if (-not $WhatIf) {
                                $ErrorMessage = "Cannot retrieve the login URL for the Compute Ops Management service!  $($_.Exception.message)"
                                throw $ErrorMessage
                            }
                        }

                        "[{0}] Login URL response: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $LoginURLResponse | Write-Verbose

                        # Add region to the global variable for the argument completer for the Region parameter of *HPECOM* cmdlets

                        $Global:HPECOMRegions += [PSCustomObject]@{
                            region      = $region
                            loginUrl    = $LoginURLResponse.login_url
                        }

                        "[{0}] Added '{1}' region to the global variable `$Global:HPECOMRegions used for the argument completer for the Region parameter of *HPECOM* cmdlets." -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose

                        # If $Global:HPECOMjobtemplatesUris is not defined, generate it using the first available COM region
                        if (-not $Global:HPECOMjobtemplatesUris) {

                            "[{0}] `$Global:HPECOMjobtemplatesUris is not defined, generating it..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            $FirstProvisionedCOMRegion = $Global:HPECOMRegions | Select-Object -first 1 | Select-Object -ExpandProperty region
                            try {
                                # Add the user to the Administrator role in Compute Ops Management
                                $_Email = $Global:HPEGreenLakeSession.username
                                Add-HPEGLRoleToUser -Email $_Email -RoleName 'Compute Ops Management administrator' | Out-Null   
                                Set-HPECOMJobTemplatesVariable -region $FirstProvisionedCOMRegion
                            }
                            catch {
                                $PSCmdlet.ThrowTerminatingError($_)
                            }

                            if ($Global:HPECOMjobtemplatesUris) {
                                "[{0}] `$Global:HPECOMjobtemplatesUris successfully generated using the '{1}' region." -f $MyInvocation.InvocationName.ToString().ToUpper(), $FirstProvisionedCOMRegion | Write-Verbose
                                Remove-HPEGLRoleFromUser -Email $_Email -RoleName 'Compute Ops Management administrator' | Out-Null   

                            }
                            else {
                                Write-Warning "Cannot generate `$Global:HPECOMjobtemplatesUris variable! Some cmdlets will fail as a result."
                            }
                        }
                        else {
                            "[{0}] `$Global:HPECOMjobtemplatesUris is already defined, skipping generation." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        }

                    }  
                }
                else {
                    throw "Service '$name' failed to provision in region '$Region'. Current status: $provision_status"
                }
                    
             
            }
        }      

        [void] $AddServiceStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $AddServiceStatus = Invoke-RepackageObjectWithType -RawObject $AddServiceStatus -ObjectName "ObjStatus.NSDE" 
            Return $AddServiceStatus
        }
    }
}

Function Remove-HPEGLService {
    <#
    .SYNOPSIS
    Remove a service from a specified region.

    .DESCRIPTION
    This Cmdlet can be used to remove a service from a region. This action is irreversible and cannot be canceled or undone once the process has begun. All users will lose access, and it will permanently delete all device and user data.

    The cmdlet issues a message at runtime to warn the user of the irreversible impact of this action and asks for a confirmation for the removal of the service.
    
    If the user confirms the action, the service is deleted. If the user cancels the action, the service is not deleted.
    
    .PARAMETER Name 
    The name of the available service to remove. This value can be retrieved from 'Get-HPEGLService -ShowProvisioned'.
        
    .PARAMETER Region 
    The name of the region where the service is removed. This value can be retrieved from 'Get-HPEGLService -ShowProvisioned'.

    .PARAMETER Force
    Forces the removal of the service without asking for confirmation. This option is useful for automation scripts that require the removal of services without user interaction.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLService -Name "Aruba Central" -Region "eu-central"

    Removes the "Aruba Central" service from the "eu-central" region after the user has confirmed the removal.

    .EXAMPLE
    Get-HPEGLService -ShowProvisioned -Name "Compute Ops Management" -Region "us-west" | Remove-HPEGLService

    Retrieves the provisioned "Compute Ops Management" service in the "us-west" region and removes it. A warning message appears and asks the user to confirm the action.

    .EXAMPLE
    Get-HPEGLService -ShowProvisioned -Name "Compute Ops Management" | Remove-HPEGLService

    Retrieves all provisioned instances of the "Compute Ops Management" service across all regions and removes them, pending user confirmation.

    .INPUTS
    System.Collections.ArrayList
        A list of services obtained from 'Get-HPEGLService -ShowProvisioned'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the service attempted to be removed.
        * Region - The name of the region where the service was removed.
        * Status - The status of the removal attempt (Failed for HTTP error return; Complete if removal is successful).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.


    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Default")]
        [ValidateNotNullOrEmpty()]
        [Alias('applicationname')]
        [String]$Name,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Default")]
        [ValidateNotNullOrEmpty()]
        [Alias('ccs_region')]
        [String]$Region,

        [Switch]$Force,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RemoveServiceStatus = [System.Collections.ArrayList]::new()


    }

    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $AppRegionfound = Get-HPEGLService -Name $name -Region $Region
        }
        catch {    
            $PSCmdlet.ThrowTerminatingError($_)
    
        }
       
        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $name
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
                                      
        }  
       
       
        if (-not $AppRegionfound) {
            # Must return a message if Service is not found in the region
            "[{0}] Service '{1}' not available in '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Service '{0}': Resource cannot be found in the workspace!" -f $Name
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Service not available in the region!"
            }



        }
        elseif (-not $AppRegionfound.provision_status) {
            # Must return a message if Service is not provisioned 
            "[{0}] Service '{1}' is not provisioned!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Service '{0}': Resource is not provisioned in any region!" -f $Name
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Service is not provisioned in any region!"
            }

        }
        else {       
           
            if (-not $Force) {

                $title = "All users will lose access and this will permanently delete all device and user data. Confirm that you would like to remove '{0}' from '{1}'." -f $name, $Region
                $question = 'This action is irreversible and cannot be canceled or undone once the process has begun. Are you sure you want to proceed?'
                
                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Confirm removal of the service. All users will lose access and all device and user data will be permanently deleted."
                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Cancel the service removal operation. The service will remain provisioned."
                $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
    
                $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
    
                if ($decision -eq 0) {
    
                    $ServiceID = $AppRegionfound.application_customer_id

                    $Uri = (Get-ApplicationProvisioningUri) + "/" + $ServiceID
        
                    # Build payload
                    $payload = ConvertTo-Json @{
                        action = "UNPROVISION"
                        
                    }
              
        
                    # Remove Service from a region. 
                    try {
    
                        Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | Out-Null
    
                        if (-not $WhatIf) {
        
                            "[{0}] '{1}' service successfully removed from '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
    
                            $objStatus.Status = "Complete"
                            $objStatus.Details = "Service successfully removed from '$Region' region"
    
                            if ($name -eq "Compute Ops Management") {

                                # 1- Remove region object from $Global:HPECOMRegions (used for the argument completer for the -Region parameter of *HPECOM* cmdlets)

                                "[{0}] ------- Deleting COM '{1}' region from `$Global:HPECOMRegions" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                               
                                $global:HPECOMRegions = @($Global:HPECOMRegions | Where-Object { $_.region -ne $region })

                                "[{0}] COM '{1}' region has been removed from `$Global:HPECOMRegions global variable" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                                
                                
                                # NOT REQUIRED ANYMORE SINCE UNIFIED API IS SUPPORTED
                                # 2- Remove API credential object from $Global:HPEGreenLakeSession.apiCredentials
                                
                                # "[{0}] ------- Deleting '{1}' temporary API client credential for region '{2}' in `$Global:HPEGreenLakeSession.apiCredentials" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                                
                                # $comApiCredential = $Global:HPEGreenLakeSession.apiCredentials | Where-Object { $_.name -match $APIClientCredentialTemplateName -and $_.name -match "COM" -and $_.region -match $Region }                          
                                # "[{0}] COM API credential found for '{1}' in `$Global:HPEGreenLakeSession.apiCredentials: `n{2} " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, $comApiCredential | Write-Verbose
                                # [void]$Global:HPEGreenLakeSession.apiCredentials.remove($comApiCredential)
                                # "[{0}] COM API credential has been removed from `$Global:HPEGreenLakeSession.apiCredentials` global variable!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose



                                # 3- Remove access token object from $Global:HPEGreenLakeSession.comApiAccessToken

                                # "[{0}] ------- Deleting '{1}' temporary API client credential for region '{2}' in `$Global:HPEGreenLakeSession.comApiAccessToken" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose

                                # $comApiAccessToken = $Global:HPEGreenLakeSession.comApiAccessToken | Where-Object { $_.name -match $APIClientCredentialTemplateName -and $_.name -match "COM" -and $_.name -match $Region }
                                # "[{0}] COM access token found for '{1}' in `$Global:HPEGreenLakeSession.comApiAccessToken: `n{2} " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, $comApiAccessToken | Write-Verbose
                                # [void]$Global:HPEGreenLakeSession.comApiAccessToken.remove($comApiAccessToken)
                                # "[{0}] COM API access token has been removed from `$Global:HPEGreenLakeSession.comApiAccessToken` global variable!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
    
                            }
                            
                        }  
                    }
                    catch {
    
                        if (-not $WhatIf) {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Service cannot be removed!" }
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                        }
                    }                          
              
                }
                else {
    
                    "[{0}] User cancelled the deletion of the service instance '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
    
                    if ($WhatIf) {
                        $ErrorMessage = "Operation cancelled by the user!"
                        Write-warning $ErrorMessage
                        return
                    }
                    else {    
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "Operation cancelled by the user! Service instance not deleted!"
                    }
                }

            }
            else {

                $ServiceID = $AppRegionfound.application_customer_id
    
                $Uri = (Get-ApplicationProvisioningUri) + "/" + $ServiceID
    
                # Build payload
                $payload = ConvertTo-Json @{
                    action = "UNPROVISION"
                    
                }
          
    
                # Remove Service from a region. 
                try {

                    Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | Out-Null

                    if (-not $WhatIf) {
    
                        "[{0}] Service successfully removed from '{1}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose

                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Service successfully removed from '$Region' region"

                        if ($name -eq "Compute Ops Management") {

                            # 1- Remove region object from $Global:HPECOMRegions (used for the argument completer for the -Region parameter of *HPECOM* cmdlets)

                            "[{0}] ------- Deleting COM '{1}' region from `$Global:HPECOMRegions" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose

                            $global:HPECOMRegions = @($Global:HPECOMRegions | Where-Object { $_.region -ne $region })

                            "[{0}] COM '{1}' region has been removed from `$Global:HPECOMRegions global variable" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                                                        
                            # NOT REQUIRED ANYMORE SINCE UNIFIED API IS SUPPORTED
                            # 2- Remove API credential object from $Global:HPEGreenLakeSession.apiCredentials
                            
                            # "[{0}] ------- Deleting '{1}' temporary API client credential for region '{2}' in `$Global:HPEGreenLakeSession.apiCredentials" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                            
                            # $comApiCredential = $Global:HPEGreenLakeSession.apiCredentials | Where-Object { $_.name -match $APIClientCredentialTemplateName -and $_.name -match "COM" -and $_.region -match $Region }                          
                            # "[{0}] COM API credential found for '{1}' in `$Global:HPEGreenLakeSession.apiCredentials: `n{2} " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, $comApiCredential | Write-Verbose
                            # [void]$Global:HPEGreenLakeSession.apiCredentials.remove($comApiCredential)
                            # "[{0}] COM API credential has been removed from `$Global:HPEGreenLakeSession.apiCredentials` global variable!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose



                            # # 3- Remove access token object from $Global:HPEGreenLakeSession.comApiAccessToken

                            # "[{0}] ------- Deleting '{1}' temporary API client credential for region '{2}' in `$Global:HPEGreenLakeSession.comApiAccessToken" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose

                            # $comApiAccessToken = $Global:HPEGreenLakeSession.comApiAccessToken | Where-Object { $_.name -match $APIClientCredentialTemplateName -and $_.name -match "COM" -and $_.name -match $Region }
                            # "[{0}] COM access token found for '{1}' in `$Global:HPEGreenLakeSession.comApiAccessToken: `n{2} " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, $comApiAccessToken | Write-Verbose
                            # [void]$Global:HPEGreenLakeSession.comApiAccessToken.remove($comApiAccessToken)
                            # "[{0}] COM API access token has been removed from `$Global:HPEGreenLakeSession.comApiAccessToken` global variable!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                        }
                        
                    }  
                }
                catch {

                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Service cannot be removed!" }
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }
                }   
            }
        }

        [void] $RemoveServiceStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $RemoveServiceStatus = Invoke-RepackageObjectWithType -RawObject $RemoveServiceStatus -ObjectName "ObjStatus.NSDE" 
            Return $RemoveServiceStatus
            
        }


    }
}

Function Add-HPEGLDeviceToService {
    <#
    .SYNOPSIS
    Assign device(s) to an HPE GreenLake service instance.

    .DESCRIPTION
    This Cmdlet assigns device(s) to an HPE GreenLake service instance.

    .PARAMETER DeviceSerialNumber 
    Specifies the serial number of the device to assign to a service instance. This value can be retrieved using 'Get-HPEGLDevice -ShowRequireAssignment'.

    .PARAMETER ServiceName 
    Specifies the name of the available service to which the device will be assigned. This value can be retrieved using 'Get-HPEGLService -ShowProvisioned'.

    .PARAMETER ServiceRegion 
    Specifies the region of the service instance. This value can be retrieved using 'Get-HPEGLService -ShowProvisioned'.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to GLP instead of sending the request. This option helps in understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Add-HPEGLDeviceToService -DeviceSerialNumber "1234567890" -ServiceName "Compute Ops Management" -Region "US-West"

    Assigns the device with the serial number '1234567890' to the "Compute Ops Management" service in the western US region.

    .EXAMPLE
    'MXQ72407P3', 'MXQ73200W1' | Add-HPEGLDeviceToService -ServiceName "Aruba Central" -Region "eu-central"

    Assigns devices with serial numbers 'MXQ72407P3' and 'MXQ73200W1' to the "Aruba Central" service in the "eu-central" region.

    .EXAMPLE
    Get-HPEGLDevice -ShowRequireAssignment | Add-HPEGLDeviceToService -ServiceName "Compute Ops Management" -Region "US-West"

    Assigns all devices that require service assignment to the "Compute Ops Management" service in the western US region.

    .EXAMPLE
    Add-Content -Path Tests\SerialNumbers.csv -Value '"Serialnumber"'
    $Serialnumbers = @('7CE244P9LM' , 'MXQ73200W1')
    $Serialnumbers | foreach { Add-Content -Path Tests\SerialNumbers.csv -Value $_ }

    Import-Csv Tests\SerialNumbers.csv | Add-HPEGLDeviceToService -ServiceName "Compute Ops Management" -Region "US-West"

    Assigns the devices listed in a CSV file to a service instance.

    .INPUTS
    System.Collections.ArrayList
        A list of devices from 'Get-HPEGLDevice -ShowRequireAssignment'.
    System.String, System.String[]
        A single string object or a list of string objects that represent the device's serial numbers.

    .OUTPUTS
    System.Collections.ArrayList
        Returns a custom status object or array of objects containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the device assigned to a service instance. 
        * Status - Status of the assignment attempt (Failed for HTTP error return; Complete if assignment is successful; Warning if no action is needed).
        * Details - More information about the status. 
        * Exception - Information about any exceptions generated during the operation.
    #>


    [CmdletBinding()]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [Alias('serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$DeviceSerialNumber,

        [Parameter (Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$ServiceName,

        [Parameter (Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$ServiceRegion,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesList = [System.Collections.ArrayList]::new()
        $DeviceIDsList = [System.Collections.ArrayList]::new()

        if (-not $ServiceName) { throw "ServiceName cannot be empty!" }
        if (-not $ServiceRegion) { throw "ServiceRegion cannot be empty!" }
        
        try {
            
            $Servicefound = Get-HPEGLService -Name $ServiceName -Region $ServiceRegion -ShowProvisioned           
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }

        if ( -not $Servicefound) {
                    
            $ErrorMessage = "Service '{0}' is not provisioned in the '{1}' region!" -f $ServiceName, $ServiceRegion
            throw $ErrorMessage
        }
        else {
            "[{0}] Service '{1}' found in '{2}' region: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRegion, ($Servicefound | convertto-json -d 5) | Write-Verbose
        }


    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Check for empty or null serial number
        if (-not $DeviceSerialNumber) {
            Write-Warning "Empty or null serial number skipped."
            continue
        }

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

        # Create a hashtable for performance
        $DeviceHashtable = @{}

        foreach ($Device in $Devices) {
            $DeviceHashtable[$Device.serialNumber] = $Device
        }
                
        "[{0}] List of device SNs to be assigned to the service: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.serialnumber | out-string) | Write-Verbose

        foreach ($Object in $ObjectStatusList) {
        
            $Device = $DeviceHashtable[$Object.SerialNumber]

            "[{0}] Processing device: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Device | convertto-json -d 5 )| Write-Verbose

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
            elseif ($device.application.id -and $null -ne $device.application.id) {

                # Must return a message if device is already assigned to a service instance 
                $Object.Status = "Warning"
                $Object.Details = "Device already assigned to a service instance!"

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource already assigned to a service instance!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }
            }
            else {      

                $DeviceId = $device.id                  

                # Building the list of device IDs object that will be assigned to the service instance
                [void]$DeviceIDsList.Add($DeviceId)
                # Add the device object to the list of devices to be assigned to the service instance
                [void]$DevicesList.Add($Object)
            }
        }

        if ($DevicesList.Count -gt 0) {

            "[{0}] List of device to be assigned to the service {1} in region {2}: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRegion, ($DevicesList | out-string) | Write-Verbose
            
            # Build the uri
            $_DevicesList = $DeviceIDsList -join ","
            "[{0}] List of device IDs to be assigned to the service: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_DevicesList | Write-Verbose

            $Uri = (Get-DevicesApplicationInstanceUri) + "?id=" + $_DevicesList

            # Build payload
            $payload = [PSCustomObject]@{ 
                application = @{
                    id = $Servicefound.application_id
                }
                region = $Servicefound.region

            } | ConvertTo-Json -Depth 5

            "[{0}] About to run a PATCH {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
            "[{0}] Payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $payload | Write-Verbose
            
                                
            # Assign Devices to service  
            try {

                $response = Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                "[{0}] Response code: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $response.code | Write-Verbose

                if (-not $WhatIf) {
                    switch ($response.code) {
                        202 {
                            foreach ($Object in $ObjectStatusList) {
                                $DeviceSet = $DevicesList | Where-Object SerialNumber -eq $Object.SerialNumber
                                if ($DeviceSet) {
                                    $Object.Status = "Complete"
                                    $Object.Details = "Device successfully assigned to the service instance!"
                                }
                            }
                        }
                        400 {
                            $Object.Status = "Failed"
                            $Object.Details = "Bad request - Device cannot be assigned to the service instance!"
                        }
                        401 {
                            $Object.Status = "Failed"
                            $Object.Details = "Unauthorized request - Device cannot be assigned to the service instance!"
                        }
                        403 {
                            $Object.Status = "Failed"
                            $Object.Details = "The operation is forbidden - Device cannot be assigned to the service instance!"
                        }
                        422 {
                            $Object.Status = "Failed"
                            $Object.Details = "Validation error. Device cannot be assigned to the service instance!"
                        }
                        429 {
                            $Object.Status = "Failed"
                            $Object.Details = "Too many requests - Device cannot be assigned to the service instance!"
                        }
                        500 {
                            $Object.Status = "Failed"
                            $Object.Details = "Internal server error - Device cannot be assigned to the service instance!"
                        }
                        default {
                            foreach ($Object in $ObjectStatusList) {
                                $DeviceSet = $DevicesList | Where-Object SerialNumber -eq $Object.SerialNumber
                                if ($DeviceSet) {
                                    $Object.Status = "Failed"
                                    $Object.Details = "Device cannot be assigned to the service instance!"
                                    $Object.Exception = "HTTP Error: $($response.httpStatusCode) - $($response.message)"
                                }
                            }
                        }
                    }
                }
            }
            catch {
                
                if (-not $WhatIf) {
                    foreach ($Object in $ObjectStatusList) {
                        $DeviceSet = $DeviceHashtable[$Object.SerialNumber]
                        If ($DeviceSet) {
                            $Object.Status = "Failed"
                            $Object.Details = "Device cannot be assigned to the service instance!"
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

Function Remove-HPEGLDeviceFromService {
    <#
    .SYNOPSIS
    Unassign device(s) from a service instance. 

    .DESCRIPTION
    This Cmdlet unassigns device(s) from an HPE GreenLake service instance.    
        
    .PARAMETER DeviceSerialNumber 
    Serial number of the device to be unassigned from a service instance. 
    This value can be retrieved from 'Get-HPEGLDevice'.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.
   
    .EXAMPLE
    Remove-HPEGLDeviceFromService -DeviceSerialNumber MXQ73200W1

    Unassigns the specified device from its service instance.

    .EXAMPLE
    Get-HPEGLDevice -Location "Mougins"  | Remove-HPEGLDeviceFromService 

    Unassigns all devices in the 'Mougins' location from their respective service instances.

    .EXAMPLE
    'MXQ72407P3', 'MXQ73200W1'  | Remove-HPEGLDeviceFromService

    Unassigns devices with serial numbers 'MXQ72407P3' and 'MXQ73200W1' from their respective service instances.

    .INPUTS
    System.Collections.ArrayList
        List of devices(s) from 'Get-HPEGLDevice'.
    System.String, System.String[]
        A single string object or a list of string objects that represent the device's serial numbers.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the device to be unassigned from a service instance. 
        * Status - Status of the unassignment attempt (Failed for http error return; Complete if unassignment is successful) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

   
   #>

    [CmdletBinding()]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [Alias('SerialNumber')]
        [ValidateNotNullOrEmpty()]
        [String]$DeviceSerialNumber,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesList = [System.Collections.ArrayList]::new()
        $DeviceIDsList = [System.Collections.ArrayList]::new()


    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Check for empty or null serial number
        if (-not $DeviceSerialNumber) {
            Write-Warning "Empty or null serial number skipped."
            continue
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{  
            SerialNumber = $DeviceSerialNumber
            Status       = $Null
            Details      = $Null
            Exception    = $Null                      
        }   

        [void] $ObjectStatusList.add($objStatus)
        
    }

    end {

        try {
            
            $devices = Get-HPEGLdevice 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        # Create a hashtable for performance
        $DeviceHashtable = @{}

        foreach ($Device in $Devices) {
            $DeviceHashtable[$Device.serialNumber] = $Device
        }
        
        "[{0}] List of device SNs to be unassigned from the service: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.serialnumber | out-string) | Write-Verbose

        foreach ($Object in $ObjectStatusList) {

            $Device = $DeviceHashtable[$Object.SerialNumber]
            
            "[{0}] Processing device: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Device | convertto-json -d 20 )| Write-Verbose

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
            elseif ( -not $device.application.id) {

                # Must return a message if device is not currently assigned to a service instance 
                $Object.Status = "Warning"
                $Object.Details = "Device not assigned to a service instance!"

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource not assigned to a service instance!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }

            }
            else {       
            
                $DeviceId = $device.id                 

                # Building the list of device IDs object that will be unassigned from the service instance
                [void]$DeviceIDsList.Add($DeviceId)

                # Add the device object to the list of devices to be unassigned from the service instance
                [void]$DevicesList.Add($Object)

            }
        }

        if ($DevicesList.Count -gt 0) {

            "[{0}] List of devices to be unassigned from the service: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DevicesList.serialNumber | Write-Verbose

            # Build the uri
            $_DevicesList = $DeviceIDsList -join ","
            "[{0}] List of device IDs to be unassigned from the service: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_DevicesList | Write-Verbose

            $Uri = (Get-DevicesApplicationInstanceUri) + "?id=" + $_DevicesList


            # Build payload
            $payload = [PSCustomObject]@{ 
                application = @{
                    id = $Null
                }
                region = $Null

            } | ConvertTo-Json -Depth 5
                        
            "[{0}] About to run a PATCH {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
            "[{0}] Payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $payload | Write-Verbose  

                                
            # Unassign Devices from service
            try {

                $response = Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                "[{0}] Response code: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $response.code | Write-Verbose

                if (-not $WhatIf) {                    
                     switch ($response.code) {
                        202 {
                            foreach ($Object in $ObjectStatusList) {
                                $DeviceSet = $DevicesList | Where-Object SerialNumber -eq $Object.SerialNumber
                                if ($DeviceSet) {
                                    $Object.Status = "Complete"
                                    $Object.Details = "Device successfully unassigned from the service instance!"
                                }
                            }
                        }
                        400 {
                            $Object.Status = "Failed"
                            $Object.Details = "Bad request - Device cannot be unassigned from the service instance!"
                        }
                        401 {
                            $Object.Status = "Failed"
                            $Object.Details = "Unauthorized request - Device cannot be unassigned from the service instance!"
                        }
                        403 {
                            $Object.Status = "Failed"
                            $Object.Details = "The operation is forbidden - Device cannot be unassigned from the service instance!"
                        }
                        422 {
                            $Object.Status = "Failed"
                            $Object.Details = "Validation error. Device cannot be unassigned from the service instance!"
                        }
                        429 {
                            $Object.Status = "Failed"
                            $Object.Details = "Too many requests - Device cannot be unassigned from the service instance!"
                        }
                        500 {
                            $Object.Status = "Failed"
                            $Object.Details = "Internal server error - Device cannot be unassigned from the service instance!"
                        }
                        default {
                            foreach ($Object in $ObjectStatusList) {
                                $DeviceSet = $DevicesList | Where-Object SerialNumber -eq $Object.SerialNumber
                                if ($DeviceSet) {
                                    $Object.Status = "Failed"
                                    $Object.Details = "Device cannot be unassigned from the service instance!"
                                    $Object.Exception = "HTTP Error: $($response.httpStatusCode) - $($response.message)"
                                }
                            }
                        }
                    }
                }
            }
            catch {
                
                if (-not $WhatIf) {
                    foreach ($Object in $ObjectStatusList) {
                        # $DeviceSet = $DevicesList | Where-Object serialNumber -eq $Object.SerialNumber
                        $DeviceSet = $DeviceHashtable[$Object.SerialNumber]
                        If ($DeviceSet) {
                            $Object.Status = "Failed"
                            $Object.Details = "Device cannot be unassigned from the service instance!"
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

Function Get-HPEGLAPIcredential {
    <#
    .SYNOPSIS
    Retrieve API credentials for an HPE GreenLake service instance.

    .DESCRIPTION
    This Cmdlet returns a collection of API credential resources for an HPE GreenLake (GLP) service instance.

    .PARAMETER Name
    Specifies the name of the API client credential to retrieve.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to GLP instead of sending the request. 
    This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLAPICredential

    Returns the API credentials for all service instances.

    .EXAMPLE
    Get-HPEGLAPICredential -Name "Grafana-COM-AP_NorthEast"

    Returns the API credential for the service instance named "Grafana-COM-AP_NorthEast".
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (ParameterSetName = 'Default')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,  

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose


        $Uri = Get-ApplicationsAPICredentialsUri

        "[{0}] Getting API client credentials from {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose

        $Services = Get-HPEGLService -ShowProvisioned
        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
       
        $ReturnData = @()

        try {
            [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

        }  
        catch {    
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if ($Null -ne $Collection ) {

            If ($Name) {

                $CollectionList = $Collection | Where-Object credential_name -eq $Name
            }
            else {

                $CollectionList = $Collection
            }

            foreach ($item in $CollectionList) {
                
                if ($item.application_instance_id -eq "00000000-0000-0000-0000-000000000000" ) {
                    # if (-not $item.associatedServiceManagerProvision ) {
                    
                    $ServiceName = "HPE GreenLake"
                    $ServiceRegion = "N/A"
                    $ConnectivityEndPoint = "https://global.api.greenlake.hpe.com"
                    
                }
                else {
               
                    $Service = $Services | Where-Object application_instance_id -eq $item.application_instance_id
                    $ServiceName = $Service | ForEach-Object name
                    $ServiceRegion = $Service | ForEach-Object region

                    if ($Service.name -eq "Data Services") {
                        $ConnectivityEndPoint = "https://sso.common.cloud.hpe.com/as/token.oauth2"
    
                    }
                    else {
                        
                        $ConnectivityEndPoint = $item.app_nbapi_endpoint
                    }

                }

                $ReturnData += $item | Select-Object  `
                @{N = "name"; E = { $item.credential_name } }, `
                @{N = "application_name"; E = { $ServiceName } }, `
                @{N = "region"; E = { $ServiceRegion } }, `
                @{N = "application_instance_id"; E = { $item.application_instance_id } }, `
                @{N = "client_id"; E = { $item.client_id } }, `
                @{N = "connectivity_endpoint"; E = { $ConnectivityEndPoint } }

            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "Service.API.Credential"         

            $ReturnData = $ReturnData | Sort-Object { $_.name }
            
            return $ReturnData 
    
        }
        else {
            return
        }
    }
}

Function New-HPEGLAPIcredential {
    <#
    .SYNOPSIS
    Creates personal API clients for a service instance.

    .DESCRIPTION
    This Cmdlet generates personal API clients for HPE GreenLake or an HPE GreenLake service instance.

    Personal API clients allow you to programmatically generate access tokens for accessing HPE GreenLake APIs using your own identity and roles. 
    
    You can maintain a maximum of 7 personal API clients.

    The prerequisite for generating an API access token is that the service instance must be provisioned/added to the user's workspace. 
    The user must have the necessary role to perform the intended operation in the service instance.

    .PARAMETER TemplateName
    Template name of the API client credential to create. This parameter automatically generates the name of the API client credential based on the template name, service name, and region.
    Format: <ServiceName>-<ServiceRegion>-<TemplateName>
    <ServiceName> can be either `COM`, `DS`, or the service name without spaces.
    Examples: "DS-US_West-Grafana", "COM-EU_Central-Ansible", "Aruba_Central-AP_Central-Terraform"

    For HPE GreenLake API client credentials:
    Format: GLP-<TemplateName>
    Examples: "GLP-Grafana", "GLP-Ansible"

    .PARAMETER ServiceName
    Name of the provisioned service accessible using the API credentials. Retrieve this value from `Get-HPEGLService -ShowProvisioned`.

    .PARAMETER Region
    Region of the service accessible using the API credentials. Retrieve this value from `Get-HPEGLService -ShowProvisioned`.

    .PARAMETER HPEGreenLake
    Switch parameter to generate API client credentials for the HPE GreenLake service.

    .PARAMETER Location
    Directory to export the API credentials to. The exported credentials include all necessary details for executing subsequent API requests.
    Exported filename format: "<Auto-generated API Credential name>_API_Credential.json".
    This parameter is optional. Note that generated API credentials are always stored during a session in `${Global:HPEGreenLakeSession.apiCredentials}`.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. Useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    New-HPEGLAPIcredential -ServiceName "Compute Ops Management" -Region "eu-central" -TemplateName POSH_Lib

    Generates a new 'COM-eu-central-POSH_Lib' API client credential for the 'Compute Ops Management' service instance in the Central Europe region.
    Adds an object containing the client_id, secure_client_secret, and connectivity_endpoint to the `${Global:HPEGreenLakeSession.apiCredentials}` variable, accessible as long as the PowerShell console is active and 'Disconnect-HPEGL' has not been executed.

    .EXAMPLE
    Get-HPEGLService -Name 'Data Services' -Region "EU-Central" | New-HPEGLAPIcredential -TemplateName Grafana -Location .

    Generates the 'DS-EU_Central-Grafana' API client credential for the 'Data Services' service instance in the Central Europe region.
    Exports the API credentials, including the client ID and secret, to a JSON file named 'DS-EU_Central-Grafana_API_Credentials.json' in the local folder.
    
    To read the encrypted API credential file contents later:
        $SecureClientSecret = (Get-Content .\DS-EU_Central-Grafana_API_Credentials.json | ConvertFrom-Json).secure_client_secret | ConvertTo-SecureString
        $Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureClientSecret)
        $ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

    Note: Decryption is only supported on the same machine where the cmdlet was executed.

    .EXAMPLE
    Get-HPEGLService -ShowProvisioned -Name 'Compute Ops Management' | New-HPEGLAPIcredential -TemplateName Grafana -Location c:\MyCredentials

    Generates API client credentials for all provisioned instances of 'Compute Ops Management'. Credential names are auto-generated from the TemplateName property, such as "COM-AP_NorthEast-Grafana" for 'Compute Ops Management AP NorthEast', and "COM-EU_Central-Grafana" for 'Compute Ops Management EU Central'.
    API credentials for each instance are exported to the c:\MyCredentials folder. Exported filenames format: 'COM-<Region_Name>-Grafana_API_Credentials.json'.

    .EXAMPLE
    # Step 1: Fetch the service details for 'Data Services' in the 'eu-west' region that is provisioned and pass that in the pipeline to create a new API client credential.
    $response = Get-HPEGLService -Name 'Data Services' -Region "eu-west" -ShowProvisioned | New-HPEGLAPIcredential -TemplateName Grafana 

    # Step 2: Extract the API credentials generated by 'New-HPEGLAPIcredential' in $Global:HPEGreenLakeSession matching the response name and current workspace ID.
    $Grafana_DS_EU_Central_Credentials = $Global:HPEGreenLakeSession.apiCredentials | Where-Object { $_.name -eq $response.Name -and $_.workspace_id -eq $Global:HPEGreenLakeSession.workspaceId }

    # Step 3: Convert the secure client secret from encrypted format to a SecureString object.
    $SecureClientSecret = $Grafana_DS_EU_Central_Credentials.secure_client_secret | ConvertTo-SecureString

    # Step 4: Marshal the SecureString to a BSTR (binary string).
    $Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureClientSecret)

    # Step 5: Convert the BSTR to a plain text string.
    $ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)

    # Step 6: Use the stored API credentials to connect to HPE Data Services (formerly known as Data Storage Cloud Services).
    Connect-DSCC -Client_Id $Grafana_DS_EU_Central_Credentials.client_id -Client_Secret $ClientSecret -GreenlakeType EU -AutoRenew -WhatIfToken

    # Explanation:
    # This script demonstrates how to pass the stored API credentials from the `$Global:HPEGreenLakeSession` global variable to `Connect-DSCC`, which initiates a connection to HPE Data Services. 
    # The `$Global:HPEGreenLakeSession` global variable remains accessible as long as the PowerShell console is active and 'Disconnect-HPEGL' has not been run.

    .INPUTS
    System.Collections.ArrayList
        List of service instance(s) from `Get-HPEGLService -ShowProvisioned`.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects with the following keys:
            * Name - name of the attempted API credential
            * Filename - name of the exported file
            * Location - path of the exported file
            * Encrypted - encryption status Boolean
            * Status - creation status (Failed for HTTP errors; Complete if successful; Warning if no action needed)
            * Details - additional status information
            * Exception - information about any exceptions during the operation

    HPEGreenLakeSession.apiCredentials
        When successful, an object is added to `${Global:HPEGreenLakeSession.apiCredentials}` with the following properties:
            ==================================================================================================
            | Name                      | Type               | Value                                         |
            |------------------------------------------------------------------------------------------------
            | name                      | String             | Name of the generated API client credential   |
            -------------------------------------------------------------------------------------------------
            | workspace_name            | String             | Name of the workspace                         |
            -------------------------------------------------------------------------------------------------
            | workspace_id              | String             | ID of the workspace                           |
            -------------------------------------------------------------------------------------------------
            | application_name          | String             | Name of the provisioned service               |
            -------------------------------------------------------------------------------------------------
            | region                    | String             | Name of the service region                    |
            -------------------------------------------------------------------------------------------------
            | application_instance_id   | String             | ID of the provisioned service instance        |
            -------------------------------------------------------------------------------------------------
            | secure_client_secret      | Secure String      | API Client Secret in a secure string format   |
            -------------------------------------------------------------------------------------------------
            | client_id                 | String             | API Client ID                                 |
            -------------------------------------------------------------------------------------------------
            | connectivity_endpoint     | String             | API connectivity endpoint                     |
            ==================================================================================================
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (Mandatory, ParameterSetName = "Default")]
        [Parameter (Mandatory, ParameterSetName = "GLP")]
        [String]$TemplateName,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Default")]
        [Alias('name')]
        [String]$ServiceName,

        [Parameter (Mandatory, ParameterSetName = "GLP")]
        [Switch]$HPEGreenLake,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Default")]
        [Alias('ccs_region')]
        [String]$Region,

        [Parameter (ParameterSetName = "Default")]
        [Parameter (ParameterSetName = "GLP")]
        [Alias ("x", "export", 'exportFile')]
        [ValidateScript({ Test-Path $_ })]
        [String]$Location,


        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-ApplicationsAPICredentialsUri
        $NewAPICredentialStatus = [System.Collections.ArrayList]::new()
        
        try {
            
            "[{0}] ------ About to run: Get-HPEGLService -ShowProvisioned" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            $Services = Get-HPEGLService -ShowProvisioned 
    
            "[{0}] ------ About to run: Get-HPEGLAPICredential" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            $Credentials = Get-HPEGLAPICredential
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        [int]$Numberofcredentials = $Credentials.count
               
    }

    Process {         

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Null
            Filename  = $Null
            Location  = $Null     
            Encrypted = $Null                       
            Status    = $Null
            Details   = $Null
            Exception = $Null
                      
        }

        if ($HPEGreenLake) {

            $ServiceName = "GLP"
            $ServiceInstanceId = "00000000-0000-0000-0000-000000000000"

            $CredentialName = $ServiceName + "-" + $TemplateName
    
            "[{0}] Credential name that will be generated: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CredentialName | Write-Verbose
            $objStatus.Name = $CredentialName 

            $Region = "N/A"
        }
        else {

            # "------ About to run: Get-HPEGLService -ShowProvisioned -Name '{0}' -Region '{1}'" -f $ServiceName, $Region | Write-Verbose
            # $service = Get-HPEGLService -ShowProvisioned -Name $ServiceName -Region $Region
            
            $service = $services | Where-Object { $_.name -eq $ServiceName -and $_.region -eq $Region }
            $ServiceInstanceId = $service.application_instance_id

            if (-not $service) {
                # Must return a message if resource not found
                "[{0}] Service '{1}' not found or not provisioned! API credential cannot be created!" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServiceName + " - " + $Region) | Write-Verbose

                if ($WhatIf) {
                    $ErrorMessage = "Service '{0}' cannot be found or is not provisioned in '{1}' region!" -f $ServiceName, $Region
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Service cannot be found in the HPE GreenLake workspace!"
                }
              
            }
            else {
            
                if ($ServiceName -eq "Compute Ops Management") {
                    $ServiceName = "COM"
                }  
                elseif ($ServiceName -eq "Data Services") {
                    $ServiceName = "DS"
                }
                else {
                    $ServiceName = $ServiceName.replace(" ", "_")
                }
           
                $CredentialName = $ServiceName + "-" + $service.region + "-" + $TemplateName
                "[{0}] Credential name that wil be generated: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CredentialName | Write-Verbose
    
                $objStatus.Name = $CredentialName 

            } 
        }      

        # Check if credential already exists or if more than 7 credentials

        # "------ About to run: Get-HPEGLAPICredential -Name '{0}'" -f $CredentialName | Write-Verbose
        # $Credentials = Get-HPEGLAPICredential
        $Credentialfound = $Credentials | Where-Object name -eq $CredentialName
            
        if ( $Credentialfound) {

            "[{0}] API credential name '{1}' already exists in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CredentialName | Write-Verbose

            # Must return a message if resource found

            if ($WhatIf) {
                $ErrorMessage = "API credential '{0}': Resource already exists in the workspace! No action needed." -f $CredentialName
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "API credential already exists in the workspace! No action needed."
            }
            
        }
        elseif ($Numberofcredentials -ge 7) {

            "[{0}] API credential '{1}' cannot be created because you have reached the maximum of 7 personal API clients." -f $MyInvocation.InvocationName.ToString().ToUpper(), $CredentialName | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "API credential '{0}': Resource cannot be created because you have reached the maximum of 7 personal API clients." -f $CredentialName
                Write-warning $ErrorMessage
                return
            }
            else {
                Throw "API credential '$($CredentialName)' cannot be created! You have reached the maximum of 7 personal API clients."
            }
        }
        else {

            $Payload = [PSCustomObject]@{
                credential_name         = $CredentialName
                application_instance_id = $ServiceInstanceId 
            } | ConvertTo-Json -Depth 5
   
            # Create API Credential  
            try {

                $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                
                Start-Sleep 1
                
                if (-not $WhatIf) {

                    if ($Region -eq "N/A") {
                        "[{0}] API credential '{1}' successfully created for '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CredentialName, $ServiceName | Write-Verbose

                    }
                    else {
                        "[{0}] API credential '{1}' successfully created for '{2}' in '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CredentialName, $ServiceName, $Region | Write-Verbose
                    }
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "API Credential successfully created"
                    $Numberofcredentials += 1
                    "[{0}] Number of credentials: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Numberofcredentials | Write-Verbose
            
                    # Save Service token 
                    # $Clientsecret = $Response.client_secret

                    $secClientSecret = ConvertTo-SecureString -String $Response.client_secret -AsPlainText -Force | ConvertFrom-SecureString  

                    $ClientID = $Response.client_id
    
                    # $ConnectivityEndpoint = (Get-HPEGLAPICredential -Name $CredentialName).connectivity_endpoint
                
                
                    $ServiceAPICredential = [PSCustomObject]@{
                        name                    = $CredentialName 
                        workspace_name          = $Global:HPEGreenLakeSession.workspace
                        workspace_id            = $Global:HPEGreenLakeSession.workspaceId
                        application_name        = $ServiceName
                        region                  = $Region
                        application_instance_id = $ServiceInstanceId
                        secure_client_secret    = $secClientSecret 
                        client_id               = $ClientID
                        connectivity_endpoint   = $Null
                        # connectivity_endpoint   = $ConnectivityEndpoint
                    }
    
                    "[{0}] API credential to add to `$Global:HPEGreenLakeSession.apiCredentials global variable: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServiceAPICredential | ConvertTo-Json -d 10) | Write-Verbose                   
                                   
                    [void]$Global:HPEGreenLakeSession.apiCredentials.Add($ServiceAPICredential)
                    "[{0}] `$Global:HPEGreenLakeSession.apiCredentials global variable set with new content" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose   
                    
                    # If the template name equal the template name set for the library temporary API credential, then set the region in $Global:HPECOMRegions global variable 
                    # This variable was used for the argument completer for the Region parameter of *HPECOM* cmdlets

                    # if ($TemplateName -eq $APIClientCredentialTemplateName -and $ServiceAPICredential.application_name -ne "GLP") {

                    #     [void]$Global:HPECOMRegions.Add($ServiceAPICredential.region)       
                        
                    #     "[{0}] Added '{1}' region to the global variable `$Global:HPECOMRegions used for the argument completer for the Region parameter of *HPECOM* cmdlets." -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $ServiceAPICredential.region | Write-Verbose

                    # }
                
                    if ($Location) {
                    
                        if ([System.IO.Path]::IsPathRooted($Location)) {

                            $objStatus.Location = $Location

                        }
                        else {
                            $objStatus.Location = (Resolve-Path $Location).Path

                        }

                        $_filename = "{0}_API_Credentials.json" -f $CredentialName

                        $objStatus.Filename = $_filename
    
                        $ServiceAPICredentialJson = $ServiceAPICredential | convertto-json -depth 99                 
                        
                        $ServiceAPICredentialJson | Out-File ($Location + '\' + $_filename)
                        "[{0}] API Client credential file '{1}' successfully created in '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_filename, ((get-Item ($Location + '\' + $_filename)).DirectoryName) | Write-Verbose
                        $objStatus.Encrypted = $False
                        
                    }
                }
            }
            catch {

                # if ($Response -match "Error status Code: 400") {
                #     "{0} API credential cannot be created because you have reached the maximum of 5 credentials" -f $CredentialName | Write-Verbose
    
                # }

                if (-not $WhatIf) {
                    
                    # Check for 403 Forbidden error (insufficient permissions)
                    $ErrorMessage = $_.Exception.Message
                    if ($ErrorMessage -match "403" -or $ErrorMessage -match "Forbidden") {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = @"
Insufficient permissions to create API credentials (403 Forbidden).

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
"@
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "API Credential cannot be created!" }
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }
                }

            }

        }

        [void] $NewAPICredentialStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            "[{0}] Adding connectivity endpoints when absent to each generated credentials" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            try {
                $Credentials = Get-HPEGLAPICredential 
           
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
                
            }

            # Collect credentials that need modification
            $credentialsToUpdate = @()

            foreach ($credential in $Global:HPEGreenLakeSession.apiCredentials) {
                if ($Null -eq $credential.connectivity_endpoint) {
                    $credentialsToUpdate += $credential
                }   
            }
    
            foreach ($credential in $credentialsToUpdate) {              
                
                $ConnectivityEndpoint = ($Credentials | Where-Object name -eq $credential.name ).connectivity_endpoint
    
                "[{0}] Removing credential `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($credential | Out-String) | Write-Verbose                
                [void]$Global:HPEGreenLakeSession.apiCredentials.Remove($credential)
                    
                $credential.connectivity_endpoint = $ConnectivityEndpoint
                # "Adding connectivity endpoint '{0}' to credential '{1}'" -f $ConnectivityEndpoint, $credential.name | Write-Verbose
                "[{0}] Adding credential `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($credential | Out-String) | Write-Verbose                
                    
                "[{0}] Saving to `$Global:HPEGreenLakeSession.apiCredentials" -f $MyInvocation.InvocationName.ToString().ToUpper() | write-Verbose
                [void]$Global:HPEGreenLakeSession.apiCredentials.Add($credential)
                
            }

            $NewAPICredentialStatus = Invoke-RepackageObjectWithType -RawObject $NewAPICredentialStatus -ObjectName "ObjStatus.NSDE" 
            Return $NewAPICredentialStatus
        }
    }
}

Function Remove-HPEGLAPICredential {
    <#
    .SYNOPSIS
    Deletes API credential of a service instance. 

    .DESCRIPTION
    This Cmdlet deletes API client credential for an HPE GreenLake service instance.
        
    .PARAMETER Name 
    Name (Case sensitve) of the API client credential to delete.

    .PARAMETER Force
    Switch parameter to force the deletion of the API credential even if it is used by the module.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.
   
    .EXAMPLE
    Remove-HPEGLAPICredential -Name "Grafana-COM-AP_NorthEast"

    Delete the API credential "Grafana-COM-AP_NorthEast".

    .EXAMPLE
    Get-HPEGLAPICredential | Where-Object name -match Grafana | Remove-HPEGLAPIcredential

    Delete all API credentials whose name matches with Grafana (such as Grafana-COM-AP_NorthEast, Grafana-COM-EU_Central, Grafana-COM-US_West).

    .EXAMPLE
    Get-HPEGLAPICredential | Remove-HPEGLAPICredential

    Delete all API credentials.

    .INPUTS
    System.Collections.ArrayList
        List of API Credential(s) from 'Get-HPEGLAPICredential'.    
    
    .OUTPUTS
    System.Collections.ArrayList    
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - name of the API credential object attempted to be deleted 
        * Status - status of the creation attempt (Failed for http error return; Complete if the deletion is successful) 
        * Details - more information about the status 
        * Exception: Information about any exceptions generated during the operation.

   #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "Default")]
        [ValidateNotNullOrEmpty()]
        [Alias ('credential_name')]
        [String]$Name,

        [Switch]$Force,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RemoveAPICredentialStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {

            $APIcredential = Get-HPEGLAPICredential -Name $Name
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }


        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
                          
        }

        if (-not $APIcredential) {
            # Must return a message if API credential not found
            "[{0}] API credential '{1}' not found!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose

            # Must return a message if resource not found

            if ($WhatIf) {
                $ErrorMessage = "API credential '{0}': Resource cannot be found in the workspace!" -f $Name
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "API credential cannot be found in the workspace!"
            }

               
        }
        else {

            # Delete API Credential  

            $Uri = (Get-ApplicationsAPICredentialsUri) + "/$Name" 
            
            # If the credential being deleted is the temporary one used by the library, send a warning 
            if (($Global:HPEGreenLakeSession.apiCredentials | Where-Object name -eq $Name) -and $Name -match $Global:HPEGLAPIClientCredentialName -and -not $Force) {

                "[{0}] Credential '{1}' is used by the module and is attempted to be removed!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose

                $title = "You are about to delete an API credential used by this module to interact with HPE GreenLake service instances. Confirm that you would like to remove '{0}'" -f $name
                $question = "This action will impact all actions because there will be no more access to these service instances. Are you sure you want to proceed?"
                
                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Confirm deletion of the API credential. This will prevent the module from accessing HPE GreenLake service instances."
                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Cancel the deletion operation. The API credential will remain active."
                $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
                
                $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)

                if ($decision -eq 0) {

                    "[{0}] User confirmed the deletion of the API credential '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose

                    try {
                    
                        Invoke-HPEGLWebRequest -Uri $Uri -method 'DELETE' -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | Out-Null
                        
                        if (-not $WhatIf) {
                            
                            "[{0}] API credential '{1}' successfully deleted!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                            $objStatus.Status = "Complete"
                            $objStatus.Details = "API Credential successfully deleted"
                            
                            # Remove credential from $Global:HPEGreenLakeSession.apiCredentials global variable
                            $APICredentialtoRemove = $Global:HPEGreenLakeSession.apiCredentials | Where-Object { $_.name -eq $Name -and $_.workspace_id -eq $Global:HPEGreenLakeSession.workspaceId } 
        
                            if ($APICredentialtoRemove) {
                            
                                "[{0}] API credential to remove from `$Global:HPEGreenLakeSession.apiCredentials global variable: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($APICredentialtoRemove | ConvertTo-Json -d 10) | Write-Verbose                   
                                [void]$Global:HPEGreenLakeSession.apiCredentials.Remove($APICredentialtoRemove)
                
                            }
        
                            Start-Sleep 1                     
        
                        }
                    }
                    catch {
        
                        if (-not $WhatIf) {
                            # Check for 403 Forbidden error (insufficient permissions)
                            $ErrorMessage = $_.Exception.Message
                            if ($ErrorMessage -match "403" -or $ErrorMessage -match "Forbidden") {
                                $objStatus.Status = "Failed"
                                $objStatus.Details = @"
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
"@
                                $objStatus.Exception = $Global:HPECOMInvokeReturnData
                            }
                            else {
                                $objStatus.Status = "Failed"
                                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "API Credential cannot be deleted!" }
                                $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                            }
                        }    
                    }

                    # COM API credentials are not used anymore
                    # Remove region if COM in $Global:HPECOMRegions tracking object used for $Region argument completer
                    # if ($APIcredential.application_name -eq "Compute Ops Management") {

                    #     [void]$Global:HPECOMRegions.Remove($APIcredential.region)       
                    #     "[{0}] Removed '{1}' region from the global variable `$Global:HPECOMRegions used for the argument completer for the Region parameter of *HPECOM* cmdlets." -f $MyInvocation.InvocationName.ToString().ToUpper(), $APIcredential.region | Write-Verbose
                    # }
                }
                else {

                    "[{0}] User cancelled the deletion of the API credential '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose

                    $objStatus.Status = "Warning"
                    $objStatus.Details = "Operation cancelled by the user! API credential not deleted!"

                }
            } 
            else {

                try {
                    
                    Invoke-HPEGLWebRequest -Uri $Uri -method 'DELETE' -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | Out-Null
                    
                    if (-not $WhatIf) {
                        
                        "[{0}] API credential '{1}' successfully deleted!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "API Credential successfully deleted"
                        
                        # Remove credential from $Global:HPEGreenLakeSession.apiCredentials global variable
                        $APICredentialtoRemove = $Global:HPEGreenLakeSession.apiCredentials | Where-Object { $_.name -eq $Name -and $_.workspace_id -eq $Global:HPEGreenLakeSession.workspaceId } 
    
                        if ($APICredentialtoRemove) {
                        
                            "[{0}] API credential to remove from `$Global:HPEGreenLakeSession.apiCredentials global variable: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($APICredentialtoRemove | ConvertTo-Json -d 10) | Write-Verbose                   
                            [void]$Global:HPEGreenLakeSession.apiCredentials.Remove($APICredentialtoRemove)
            
                        }
    
                        Start-Sleep 1                     
    
                    }
                }
                catch {
    
                    if (-not $WhatIf) {
                        # Check for 403 Forbidden error (insufficient permissions)
                        $ErrorMessage = $_.Exception.Message
                        if ($ErrorMessage -match "403" -or $ErrorMessage -match "Forbidden") {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = @"
Insufficient permissions to remove API credentials (403 Forbidden).

ROLES THAT CANNOT MANAGE API CREDENTIALS:
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
You need a role with platform or workspace-level API credential management permissions, such as:
- Account Administrator
- Workspace Administrator
- Platform roles with API credential management rights

SOLUTIONS:
1. Contact your Workspace Administrator or Account Administrator to grant you the appropriate role
2. Have an administrator manually remove the API credentials
3. Use a different user account that has Administrator privileges

For more information: https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us
"@
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "API Credential cannot be deleted!" }
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                        }
                    }    
                }
            }
        }  

        [void] $RemoveAPICredentialStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $RemoveAPICredentialStatus = Invoke-RepackageObjectWithType -RawObject $RemoveAPICredentialStatus -ObjectName "ObjStatus.NSDE" 
            Return $RemoveAPICredentialStatus
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


# Private functions (not exported)

# Required by New-HPEGLService to generate $Global:HPECOMjobtemplatesUris when creating the first COM service instance
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



# Export only public functions and aliases
Export-ModuleMember -Function 'Get-HPEGLService', 'Get-HPEGLServiceScopeFilter', 'Get-HPEGLServiceResourceRestrictionPolicy', 'New-HPEGLService', 'Remove-HPEGLService', 'Add-HPEGLDeviceToService', 'Remove-HPEGLDeviceFromService', 'Get-HPEGLAPIcredential', 'New-HPEGLAPIcredential', 'Remove-HPEGLAPICredential' -Alias *

# SIG # Begin signature block
# MIItTQYJKoZIhvcNAQcCoIItPjCCLToCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBSCXD9ti6zDp+8
# /HHUrbMrXBSubm1QUDHnJX/Jftj3MqCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgndElTajBBtMI414AV/g1+2RJSI3wmYIIEGX14TTHl44wDQYJKoZIhvcNAQEB
# BQAEggIAWVwe3L1yyesQP3CgdLM8zyibPchC1FTnauzofnbTFKpm9HPd9dJmfAJ2
# /GZqvQmTpL9iYTCH0oDUDXE8Z8Yur/opDBXwvQAQwsz2OfimPq0o4TQvCFlSk7Ka
# s6RAwYxqEcEOjhFMFECwf0U/VjySkv6yMbPwd0VPZfXqP0dmdDXv2hQv6Bc2n0+c
# zCHlXHbGqexCVNrQA+Dw92ETh5Lje/+hdfm2Zor3yMmUZwcyKjzwJ320ih91jgX/
# qIe96nGVeWynL8ACflfH5UR3Q6Uf3QysWwhHY8JXOcIyLh+8ALYPqcuBTxB/Zxyn
# UcD/qAfCiiMv6cHpybvKZQThJFfLchitPyJKaAUTED3elCwJf9plWxZtKKyxDani
# 0wVlTZdxZY2+Yctz9OpskV4Fxri7aKz6Xpq5mzQ6uMflxJo5k/l7kfF5GVRRo12e
# +LOJrqH/HJtjvfQW/BEwUKGC3aUNiL3Jm7eUftt22+NntmtrzwTW5/0j8wAcPWj7
# RuU2qmediuh3ln1uafQuMyiNv9UTTgnSuQWoKYu2XCdPNdD+WRnuWNJYMXUa5d3K
# nfRu0EudZep2gH0/hsA5BHrAd4kllZ8lbT/PQA2omEaJGicKaQBhk8kWCfEWrWKf
# KHPTOAebzsa+kvUSnxTBQT/a9IR6LM32189m92ihNTocn9bQ4NWhgheXMIIXkwYK
# KwYBBAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMNsQ+xkF6fdzZewJQ3oGohG/uLO0tBwpIL1hcJb9HWZe
# 38m4lu/pJJdTIzBnXC4BJgIQfAQGlUoA3Po2T91azoLKjhgPMjAyNjAxMzAxMDUz
# MjZaoIITOjCCBu0wggTVoAMCAQICEAwgQ0n50PdZ+5gt5AgbiHswDQYJKoZIhvcN
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
# CSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYwMTMw
# MTA1MzI2WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBRyvP2gEH9JNLAHHGEP5teW
# UACYdzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCAy8+OxvaLXsm1PHRuM3b2Pi4R2
# oXie1hLNPKp6nv81wjA/BgkqhkiG9w0BCQQxMgQw3n2ItFn5omwzs1Vw60ryGekw
# FW25JAB5fXWtAbs/8NJKRJaVekc5DKHfJEZoNT9AMA0GCSqGSIb3DQEBAQUABIIC
# AC4NZypF1uwGQ9Uy0UIp3BnI3h/9jzZ5nnGKNRghNQ6ItXJ7VGY254vibwDBXwqF
# KtFYu0MHDq7mq31oDOnCxVs3sMNspt0pTsTcS1RjgpBFOsQuAIES00s3rvpi0Db2
# G7h4x9G1KZfGPWDXn245pNsiD4UMgiz60ZK/hTHc8qmi095759Yw0lvyx7KDbguk
# odZbotBIUi1DHcc4Ub5jMjAoTCdVO2/HmD1U7YoQX35jBaFGrJwoxA3J6Rc4RvBo
# FEh68KOujqQy30SyT3k8BwSSKYqgVTSiy8ns9q67XtMQIakCnMMj8eMV/bqaqq6B
# +K/1ZIrf6Cmns9j6IrS4lhw1eDwHjRSp19SICtoxe1BXtT5N2Db7JAxBgbuBigZh
# NzBeeqnvZG8kbgiylzC3y2XAkPaA3rF/kLBcBJ2B/vnDlTUB3VLchIZ8hrR0wxjt
# 3s3b4YYrN2y/3iU0wGHHkl5C0fmgTlQOKQRlLDzky1pNIzcah2+ie76rGRFE3+0T
# /SUROkX/pOOmdDlmD/w2clMr6OlBydX04/9+sa1f49+3i5Qx3os0V7a7vkwpEq2D
# 7lGaf9kfgNTgrk8BuGCnuNBCF89aXHF7MRB0/PThfbxj8pGQuRaTMNwq70j+QokV
# 16GJktMcEv7DL0j7z0mdE4nOu5GVQtT1QfbSLclYBzsm
# SIG # End signature block
