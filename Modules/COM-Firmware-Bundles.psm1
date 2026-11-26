#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT FIRMWARE BUNDLES -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
Function Get-HPECOMFirmwareBaseline {
    <#
    .SYNOPSIS
    Retrieve the list of firmware baselines.

    .DESCRIPTION
    This Cmdlet returns a collection of firmware baselines (formerly called "Firmware Bundles") that are available in the specified region.
    
    Note: The function name 'Get-HPECOMFirmwareBundle' is supported as an alias for backward compatibility.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER ReleaseVersion 
    Optional parameter that can be used to specify the release version of firmware bundles to display.
    
    .PARAMETER LatestVersion 
    Optional parameter that can be used to display the latest appliance firmware bundles version.

    .PARAMETER IsActive 
    Optional switch parameter that can be used to only get the supported firmware bundles.

    .PARAMETER BundleType 
    Optional parameter parameter that can be used to specify the bundle type of firmware baselines to display such as 'BASE', 'PATCH' and 'HOTFIX'. 

    .PARAMETER Generation 
    Optional parameter parameter that can be used to specify the server generation of firmware baselines to display such as '10', '11'... 

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMFirmwareBaseline -Region us-west 

    Return all firmware baselines resources located in the western US region. 

    .EXAMPLE
    Get-HPECOMFirmwareBaseline -Region us-west -BundleType BASE  

    Return all firmware baselines type base resources located in the western US region. 

    .EXAMPLE
    Get-HPECOMFirmwareBaseline -Region eu-central  -IsActive -Generation 11 -LatestVersion

    Return the latest and supported firmware baseline located in the central EU region for Gen11 servers.

    .EXAMPLE
    Get-HPECOMFirmwareBaseline -Region us-west -ReleaseVersion 2023.10.00.01 -IsActive 

    Return all firmware baselines 2023.10.00.01 resources that are active (supported). 

    .EXAMPLE
    Get-HPECOMFirmwareAnalysisReport -Region eu-central -ShowAdvisories

    Return the security bulletins and customer advisories resolved by the latest baselines, to assess the benefit of an update before choosing a baseline.

    .INPUTS
    No pipeline support

   
    
   #>
    [CmdletBinding(DefaultParameterSetName = 'ReleaseVersion')]
    [Alias('Get-HPECOMFirmwareBundle')]
    Param( 
    
        [Parameter (Mandatory)] 
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

        [Parameter (ParameterSetName = 'ReleaseVersion')]
        [ValidateNotNullOrEmpty()]
        [String]$ReleaseVersion,
        
        [Parameter (ParameterSetName = 'Latest')]
        [Switch]$LatestVersion,

        [Switch]$IsActive,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $environments = @('BASE', 'PATCH', 'HOTFIX')
                $filteredEnvironments = $environments | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredEnvironments | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateScript({
                $validOptions = @('BASE', 'PATCH', 'HOTFIX')
                
                if ($validOptions -contains $_) {
                    $True
                }
                else {
                    throw "'$_' is not a valid option."
                }
                
            })]            
        [String]$BundleType,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('10', '11', '12')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('10', '11', '12')]
        [String]$Generation,


        [Switch]$WhatIf
       
    ) 


    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
      
    }
      
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose      
        
        $Uri = Get-COMFirmwareBundlesUri

        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
                   
        }           
        

        $ReturnData = @()
       
        if ($Null -ne $CollectionList) {     

            if ($ReleaseVersion) {

                $CollectionList = $CollectionList | Where-Object releaseVersion -eq $ReleaseVersion

            }   
            if ($IsActive) {

                $CollectionList = $CollectionList | Where-Object isActive -match $IsActive

            }   
            if ($Generation) {

                $CollectionList = $CollectionList | Where-Object bundleGeneration -match $Generation

            }   
            if ($BundleType) {

                $CollectionList = $CollectionList | Where-Object bundleType -match $BundleType

            }   

            if ($LatestVersion) {
                $maxVersion = $CollectionList | ForEach-Object { [version]$_.releaseVersion } | Sort-Object -Descending | Select-Object -First 1
                Write-Verbose "Max releaseVersion: $maxVersion"
                $CollectionList = $CollectionList | Where-Object { [version]$_.releaseVersion -eq $maxVersion }
                Write-Verbose "Items with max releaseVersion: $($CollectionList | Out-String)"
            }

            # Add region and a true [version]-typed property for correct numeric sorting
            $CollectionList | ForEach-Object {
                $_ | Add-Member -Type NoteProperty -Name region  -Value $Region -Force
                $_ | Add-Member -Type NoteProperty -Name version -Value ([version]$_.releaseVersion) -Force
            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.FirmwareBaselines"    
    
            $ReturnData = $ReturnData | Sort-Object version -Descending
        
            return $ReturnData 
                
        }
        else {

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
Export-ModuleMember -Function 'Get-HPECOMFirmwareBaseline' -Alias 'Get-HPECOMFirmwareBundle'


# SIG # Begin signature block
# MIIn2gYJKoZIhvcNAQcCoIInyzCCJ8cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC1VLWToAaGuhtk
# Cm2I6/DjBVNV7gqmEIHIRRpDCj4B1qCCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
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
# GTU1MVGm689DXoHgr74GU9k1qmQ8Gtxnjsmyw0H1cTgwDQYJKoZIhvcNAQEBBQAE
# ggIA0fTTBgzyXKAJ+BtxU2W578APDvwHAfhDtzcnAm7kYujwZGduoVRRbjahIiCm
# F3sKppwXNR6Ni4kWhzjhwMksmh6wNP/lkfYd6aojut6i/yVWBjJEMYDvaXTxw3Lh
# NHM+f2f1DAB081BU5o0ACzFIeFpdmHCgsjrCBn+7jWZFVMjmBfczTzUYtELWgnLg
# muway8rIhQMYvQLw4kVSwN1xvNg3WAW8QYivFVmnqDIAnctvUvTLQdUO809EytJO
# q1VYEEZxjVcYAYGamovadVxLLY7ZH2u9O1m2eESDjpuHxpgD7PzR37TtNk0twhH4
# lU4LObz4qSeoSAVyyAyxPjvLX2xctlqI2FEqoQUIrHbHnvx/t25Zwzq5g+82oKR4
# WftGpSVscKFgvOVja+VOtHresHI2oYAf6FMdD6lQy8wMAoRu34uLz986Do7p1O5p
# G2jXMabnhYxpdtEmvRhd6f+jItQCRF+5AjwQJ/dVnyPvR20v1D27bSsEjBefeBMo
# DUFT1tBOqYM1eM5HxI4fnuQfxXcT7uXXic8QYPTvK2b/18YwONTmKfkZGXkR+Ymm
# 6oi3PBtndla2OdmYU8yDIY+zXcE4theP5CfNIYugVAluc330wOuxcz5wgpcTDHY8
# rU6rEOykJqYx+Ncwzr4TOmXAXxHCGk6DINcIfgNKg56JtVOhgheXMIIXkwYKKwYB
# BAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEwDQYJ
# YIZIAWUDBAICBQAEMMGAQo0RB8V+9dAkfUf8zC9i/08WH6taBSwtEBiwfPIBBXEG
# WHx4b+cOyrPG0rNw7gIQV7bb6mbi5sdAPR47iSfviBgPMjAyNjExMjYxNzQ5MTJa
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
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYxMTI2MTc0
# OTEyWjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTpqKcjtIUE9eDhQ4tnPs6HzyxQ
# mzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCBxHdd7HC5xsmHXVY1pnAB3yX0SAzCa
# YI7cEFY0wVBQezA/BgkqhkiG9w0BCQQxMgQwaYXGPTaxQ8Y1SZYDQYYKk7VW570e
# 2rZHkQCPfbiBqX2Khyoes4JgVJigpUcbmaJsMA0GCSqGSIb3DQEBAQUABIICAGLn
# 5r6/wkBhJrAhD38VF+/MzLcspOCGWhZEW0iMV0UyEEV7KSVDurxn44ZWfj7jaLoN
# ST0g+1+zXnntM6ACCLzV6uRWNloxk4Ug9MQ2VFOj2hHF6kYGx77gcaNKURTnbwpX
# cirgUO/LfHdFStEeY2GBvJhvLGw+LvKtCwr+ZmaHK6tExh24n3H7eqBdiSn/ZGhw
# vrv1p8wTcJFAt5iDDEZKS96PNmjB7UJkL6Zw9Ofe6ZkrAMRRELNQMC46noBll1Nf
# k+WMjQU285fEXOtYXV5vx1oMkWCWu19oaIPY/N5tIes8OYRRRikR9ARsilJDJLk7
# zgcccJHddRpuwX16Rn8PTjb2LcCjLvLuQ14PIYdRUDoxbNvk6T1aeweQdmGBvOOf
# zWKjv/qrfHPACojq0ad4k+k0YpvNEXrRYAZ+7m608NFe/UVt65tdKOldKIpFX0R3
# KtqUTmx7NqiMRkw0Ygp06issZ7Dw9TReJhKPTM1LPbKBnpmfVTqsBEOCf27VMD3e
# CfriTZ8vUSd3r0vafeb1PttoG8tDZPo2a45boen4MR158B9FcroVac3rxTNygH9S
# EF8iDKDzg2eo2G4A7RPwAVs8NDnTsMyIyATYAKcDgcx2aETy5CL590lZyyTGfpYU
# +4M0/E47BZ8hpqG93pDaE2lgwkLQRYG/YkzSw6OX
# SIG # End signature block
