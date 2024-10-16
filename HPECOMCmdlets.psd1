#
# Module manifest for module 'HPECOMCmdlets'
#
# Generated by: Lionel Jullien
#
# Generated on: 10/16/2024
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'HPECOMCmdlets.psm1'

# Version number of this module.
ModuleVersion = '1.0.5'

# Supported PSEditions
CompatiblePSEditions = 'Desktop', 'Core'

# ID used to uniquely identify this module
GUID = '2d56b651-74de-4f5b-9fbb-bf84c4e7d75b'

# Author of this module
Author = 'Lionel Jullien'

# Company or vendor of this module
CompanyName = 'Hewlett-Packard Enterprise'

# Copyright statement for this module
Copyright = '(C) Copyright 2013-2024 Hewlett Packard Enterprise Development LP

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the "Software"), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in
        all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
        THE SOFTWARE.'

# Description of the functionality provided by this module
Description = 'HPE Compute Ops Management PowerShell library'

# Minimum version of the PowerShell engine required by this module
PowerShellVersion = '5.1'

# Name of the PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module. This prerequisite is valid for the PowerShell Desktop edition only.
# ClrVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
FormatsToProcess = 'HPECOMCmdlets.Format.ps1xml'

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Get-HPECOMServerLocation', 'Add-HPECOMServerToGroup',
               'Add-HPEGLDeviceCompute', 'Add-HPEGLDeviceNetwork',
               'Add-HPEGLDeviceStorage', 'Add-HPEGLDeviceTagToDevice',
               'Add-HPEGLDeviceToService', 'Add-HPEGLRoleToUser', 'Connect-HPEGL',
               'Connect-HPEGLDeviceComputeiLOtoCOM', 'Connect-HPEGLWorkspace',
               'Disable-HPECOMEmailNotificationPolicy',
               'Disable-HPECOMIloIgnoreSecuritySetting',
               'Disable-HPECOMServerAutoiLOFirmwareUpdate', 'Disable-HPEGLDevice',
               'Disconnect-HPEGL', 'Enable-HPECOMEmailNotificationPolicy',
               'Enable-HPECOMIloIgnoreSecuritySetting',
               'Enable-HPECOMServerAutoiLOFirmwareUpdate', 'Enable-HPEGLDevice',
               'Get-HPECOMActivity', 'Get-HPECOMApplianceFirmwareBundle',
               'Get-HPECOMEmailNotificationPolicy', 'Get-HPECOMExternalService',
               'Get-HPECOMFilter', 'Get-HPECOMFirmwareBundle', 'Get-HPECOMGroup',
               'Get-HPECOMGroupFirmwareCompliance', 'Get-HPECOMJob',
               'Get-HPECOMJobTemplate', 'Get-HPECOMMetricsConfiguration',
               'Get-HPECOMOneViewAppliance', 'Get-HPECOMReport',
               'Get-HPECOMSchedule', 'Get-HPECOMServer',
               'Get-HPECOMServerActivationKey', 'Get-HPECOMServerBySerialNumber',
               'Get-HPECOMServerInventory', 'Get-HPECOMSetting',
               'Get-HPECOMSustainabilityReport', 'Get-HPECOMWebhook',
               'Get-HPEGLAPIcredential', 'Get-HPEGLAuditLog', 'Get-HPEGLdevice',
               'Get-HPEGLDeviceAutoSubscription', 'Get-HPEGLDeviceSubscription',
               'Get-HPEGLJWTDetails', 'Get-HPEGLLocation',
               'Get-HPEGLResourceRestrictionPolicy', 'Get-HPEGLRole',
               'Get-HPEGLService',
               'Get-HPEGLServiceResourceRestrictionPolicyFilter',
               'Get-HPEGLServiceSubscription', 'Get-HPEGLUser',
               'Get-HPEGLUserAccountDetails', 'Get-HPEGLUserPreference',
               'Get-HPEGLUserRole', 'Get-HPEGLWorkspace',
               'Invoke-HPECOMGroupBiosConfiguration',
               'Invoke-HPECOMGroupExternalStorageComplianceCheck',
               'Invoke-HPECOMGroupExternalStorageConfiguration',
               'Invoke-HPECOMGroupFirmwareComplianceCheck',
               'Invoke-HPECOMGroupInternalStorageConfiguration',
               'Invoke-HPECOMGroupOSInstallation', 'Invoke-HPECOMWebRequest',
               'Invoke-HPEGLWebRequest', 'New-HPECOMApplianceOneView',
               'New-HPECOMExternalService', 'New-HPECOMFilter', 'New-HPECOMGroup',
               'New-HPECOMServerInventory', 'New-HPECOMSettingServerBios',
               'New-HPECOMSettingServerExternalStorage',
               'New-HPECOMSettingServerFirmware',
               'New-HPECOMSettingServerInternalStorage',
               'New-HPECOMSettingServerOSImage', 'New-HPECOMSustainabilityReport',
               'New-HPECOMWebhook', 'New-HPEGLAPIcredential',
               'New-HPEGLDeviceSubscription', 'New-HPEGLLocation',
               'New-HPEGLResourceRestrictionPolicy', 'New-HPEGLService',
               'New-HPEGLWorkspace', 'Remove-HPECOMApplianceOneView',
               'Remove-HPECOMExternalService', 'Remove-HPECOMFilter',
               'Remove-HPECOMGroup', 'Remove-HPECOMOneViewServerLocation',
               'Remove-HPECOMSchedule', 'Remove-HPECOMServerFromGroup',
               'Remove-HPECOMSetting', 'Remove-HPECOMWebhook',
               'Remove-HPEGLAPICredential', 'Remove-HPEGLDeviceAutoSubscription',
               'Remove-HPEGLDeviceFromService', 'Remove-HPEGLDeviceLocation',
               'Remove-HPEGLDeviceSubscription', 'Remove-HPEGLDeviceTagFromDevice',
               'Remove-HPEGLLocation', 'Remove-HPEGLResourceRestrictionPolicy',
               'Remove-HPEGLRoleFromUser', 'Remove-HPEGLService', 'Remove-HPEGLUser',
               'Restart-HPECOMserver', 'Send-HPECOMWebhookTest',
               'Send-HPEGLUserInvitation', 'Set-HPECOMExternalService',
               'Set-HPECOMFilter', 'Set-HPECOMGroup',
               'Set-HPECOMOneViewServerLocation', 'Set-HPECOMSchedule',
               'Set-HPECOMSettingServerBios',
               'Set-HPECOMSettingServerExternalStorage',
               'Set-HPECOMSettingServerFirmware',
               'Set-HPECOMSettingServerInternalStorage',
               'Set-HPECOMSettingServerOSImage', 'Set-HPECOMWebhook',
               'Set-HPEGLDeviceAutoSubscription', 'Set-HPEGLDeviceLocation',
               'Set-HPEGLDeviceSubscription', 'Set-HPEGLLocation',
               'Set-HPEGLUserAccountDetails', 'Set-HPEGLUserAccountPassword',
               'Set-HPEGLUserPreference', 'Set-HPEGLWorkspace', 'Start-HPECOMserver',
               'Stop-HPECOMGroupFirmware', 'Stop-HPECOMserver',
               'Test-HPECOMExternalService', 'Update-HPECOMApplianceFirmware',
               'Update-HPECOMGroupFirmware', 'Update-HPECOMServerFirmware',
               'Update-HPECOMServeriLOFirmware', 'Wait-HPECOMJobComplete'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
# CmdletsToExport = @()

# Variables to export from this module
# # VariablesToExport = @()

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
# AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = 'Compute-Ops-Management','COM','GLP','Hewlett-Packard-Enterprise','HPE','GreenLake','HPEGreenLake'

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/jullienl/HPE-COM-PowerShell-library/tree/main?tab=MIT-1-ov-file'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/jullienl/HPE-COM-PowerShell-library'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = '
- Changed module name to HPECOMCmdlets
- Renamed library to ''HPE Compute Ops Management PowerShell Library''
'

        # Prerelease string of this module
        # Prerelease = ''

        # Flag to indicate whether the module requires explicit user acceptance for install/update/save
        # RequireLicenseAcceptance = $false

        # External dependent modules of this module
        # ExternalModuleDependencies = @()

    } # End of PSData hashtable

 } # End of PrivateData hashtable

# HelpInfo URI of this module
HelpInfoURI = 'https://github.com/jullienl/HPE-COM-PowerShell-library/blob/main/README.md'

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''

}


# SIG # Begin signature block
# MIItlQYJKoZIhvcNAQcCoIIthjCCLYICAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCTgtaJ4fVfEZga
# 74rNtIFJvbni3QdXZo7zK/FzQP99LKCCEXYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggXhMIIESaADAgECAhEA83w3
# gf2o8H0GHWXSUybisjANBgkqhkiG9w0BAQwFADBUMQswCQYDVQQGEwJHQjEYMBYG
# A1UEChMPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBD
# b2RlIFNpZ25pbmcgQ0EgUjM2MB4XDTIyMDYwNzAwMDAwMFoXDTI1MDYwNjIzNTk1
# OVowdzELMAkGA1UEBhMCVVMxDjAMBgNVBAgMBVRleGFzMSswKQYDVQQKDCJIZXds
# ZXR0IFBhY2thcmQgRW50ZXJwcmlzZSBDb21wYW55MSswKQYDVQQDDCJIZXdsZXR0
# IFBhY2thcmQgRW50ZXJwcmlzZSBDb21wYW55MIIBojANBgkqhkiG9w0BAQEFAAOC
# AY8AMIIBigKCAYEA3nXTSeo4pVdKrf7RlSd2tDEbwbNsAuOo9sKzn6H1kVFshc5b
# ALe9NHmnAsdDFhmcriSrlCPsKekOpmBzUY+hjMTv7eF99bR1rA5tvQQvEdkGkzyN
# 2ZpFc2h7WiImjuGapcXXu8YpSm9seDgSbKnLtS/WAer5K/x30t4BBXm4j7nScY6E
# 0V3ZwkueiVNq0uiUjmGXxqzDgPQmP4H9Gt5mfrQdmpFMccfv9KC4TbbT0m0WHZte
# ebUIBJCWyJQHNJZES9oytn10QoSeBxclInXGzG7q6PIkyXSds7RsBm25gmBRvrm8
# Uf33JnfBEyyd6AH0nfSUVylOYlrLexniH5Kdrq96spk9Wj+7pq5fSXcjULZSunMN
# 6gIrQG+d7NvxuaUkjwDx+3k/A0daJc4hiHcOJa4kjK2SmQ3e27Z4FsiTUWk88C+t
# 1yya6Q/KmT8DcTfHOBpyF0mDEPJYsU5X/jquFRNrG6fzDuKkse3MEbc641HDap/n
# Ldwm7gztHt/IFc4JAgMBAAGjggGJMIIBhTAfBgNVHSMEGDAWgBQPKssghyi47G9I
# ritUpimqF6TNDDAdBgNVHQ4EFgQU9ol95gfMeTfyaXeTTny+MR/YG/UwDgYDVR0P
# AQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwMwSgYD
# VR0gBEMwQTA1BgwrBgEEAbIxAQIBAwIwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9z
# ZWN0aWdvLmNvbS9DUFMwCAYGZ4EMAQQBMEkGA1UdHwRCMEAwPqA8oDqGOGh0dHA6
# Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nQ0FSMzYu
# Y3JsMHkGCCsGAQUFBwEBBG0wazBEBggrBgEFBQcwAoY4aHR0cDovL2NydC5zZWN0
# aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNpZ25pbmdDQVIzNi5jcnQwIwYIKwYB
# BQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4IB
# gQAdJNlWSujYBAZ1mdIy0Q66db+4YWP+FbaUiQWNqbfi30s7Ctg70/2t0n1QDDkg
# hWHFM2kcdy1PGh4fOMeRSfIhsTre54YcsNe5wELSJQbvN8lfPYXMThb3n4/BXxoD
# 1zx5rmcwGPXVF5oIZJub5FzMNVpECjy8C42skTFXv4eB/yEHKI/BWsjvnkldkNEG
# 3v8Y/23gGHruFy2qVW50xyH8zsjd+gIStVojyhPJ0jgtZvXgxwVJYwBGJwgYOO+q
# pRnuUp4Bse+KlA8Ttm+Q4Nx8qOJYBE44Qi8BUXwoEDs26pFIyNuszBFuzeyL4Wkx
# y7srdCWYCIyLbD5b7WFbhd2ieK2Mg+WtZJNB3t8ZpdLLkH4vPmZGIo4FkeAST1I1
# XtKp5PqLhzPEZbsY9JL8i6XvedCL8cHe1zVX3eM9EPL/jxw9kLcFrFN+DQ1wIHCc
# gEH7/RYXc9abuGcC2XpP4YbzSMWbff8X/Pgw8HA8aSRhctF+bz7dI+/REmlDJtdP
# T6wwggYaMIIEAqADAgECAhBiHW0MUgGeO5B5FSCJIRwKMA0GCSqGSIb3DQEBDAUA
# MFYxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLTArBgNV
# BAMTJFNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBSb290IFI0NjAeFw0yMTAz
# MjIwMDAwMDBaFw0zNjAzMjEyMzU5NTlaMFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQK
# Ew9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMTIlNlY3RpZ28gUHVibGljIENvZGUg
# U2lnbmluZyBDQSBSMzYwggGiMA0GCSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQCb
# K51T+jU/jmAGQ2rAz/V/9shTUxjIztNsfvxYB5UXeWUzCxEeAEZGbEN4QMgCsJLZ
# UKhWThj/yPqy0iSZhXkZ6Pg2A2NVDgFigOMYzB2OKhdqfWGVoYW3haT29PSTahYk
# wmMv0b/83nbeECbiMXhSOtbam+/36F09fy1tsB8je/RV0mIk8XL/tfCK6cPuYHE2
# 15wzrK0h1SWHTxPbPuYkRdkP05ZwmRmTnAO5/arnY83jeNzhP06ShdnRqtZlV59+
# 8yv+KIhE5ILMqgOZYAENHNX9SJDm+qxp4VqpB3MV/h53yl41aHU5pledi9lCBbH9
# JeIkNFICiVHNkRmq4TpxtwfvjsUedyz8rNyfQJy/aOs5b4s+ac7IH60B+Ja7TVM+
# EKv1WuTGwcLmoU3FpOFMbmPj8pz44MPZ1f9+YEQIQty/NQd/2yGgW+ufflcZ/ZE9
# o1M7a5Jnqf2i2/uMSWymR8r2oQBMdlyh2n5HirY4jKnFH/9gRvd+QOfdRrJZb1sC
# AwEAAaOCAWQwggFgMB8GA1UdIwQYMBaAFDLrkpr/NZZILyhAQnAgNpFcF4XmMB0G
# A1UdDgQWBBQPKssghyi47G9IritUpimqF6TNDDAOBgNVHQ8BAf8EBAMCAYYwEgYD
# VR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcDAzAbBgNVHSAEFDAS
# MAYGBFUdIAAwCAYGZ4EMAQQBMEsGA1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwu
# c2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY0NvZGVTaWduaW5nUm9vdFI0Ni5jcmww
# ewYIKwYBBQUHAQEEbzBtMEYGCCsGAQUFBzAChjpodHRwOi8vY3J0LnNlY3RpZ28u
# Y29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ1Jvb3RSNDYucDdjMCMGCCsGAQUF
# BzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEA
# Bv+C4XdjNm57oRUgmxP/BP6YdURhw1aVcdGRP4Wh60BAscjW4HL9hcpkOTz5jUug
# 2oeunbYAowbFC2AKK+cMcXIBD0ZdOaWTsyNyBBsMLHqafvIhrCymlaS98+QpoBCy
# KppP0OcxYEdU0hpsaqBBIZOtBajjcw5+w/KeFvPYfLF/ldYpmlG+vd0xqlqd099i
# ChnyIMvY5HexjO2AmtsbpVn0OhNcWbWDRF/3sBp6fWXhz7DcML4iTAWS+MVXeNLj
# 1lJziVKEoroGs9Mlizg0bUMbOalOhOfCipnx8CaLZeVme5yELg09Jlo8BMe80jO3
# 7PU8ejfkP9/uPak7VLwELKxAMcJszkyeiaerlphwoKx1uHRzNyE6bxuSKcutisqm
# KL5OTunAvtONEoteSiabkPVSZ2z76mKnzAfZxCl/3dq3dUNw4rg3sTCggkHSRqTq
# lLMS7gjrhTqBmzu1L90Y1KWN/Y5JKdGvspbOrTfOXyXvmPL6E52z1NZJ6ctuMFBQ
# ZH3pwWvqURR8AgQdULUvrxjUYbHHj95Ejza63zdrEcxWLDX6xWls/GDnVNueKjWU
# H3fTv1Y8Wdho698YADR7TNx8X8z2Bev6SivBBOHY+uqiirZtg0y9ShQoPzmCcn63
# Syatatvx157YK9hlcPmVoa1oDE5/L9Uo2bC5a4CH2Rwxght1MIIbcQIBATBpMFQx
# CzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMT
# IlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYCEQDzfDeB/ajwfQYd
# ZdJTJuKyMA0GCWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIBDDECMAAwGQYJKoZI
# hvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcC
# ARUwLwYJKoZIhvcNAQkEMSIEIHcOCThffh59it3/bErj/1jlHaAQyGlvUZsWpHQt
# 40L/MA0GCSqGSIb3DQEBAQUABIIBgJLMYxGAbDgUN1P60V3NxUG5CcRzivFCqB01
# 7t5ji/4dey3KULtgtJzOfYkAnQ1LzzxZZbr57HoHESpmK506lKsGLGD8mZOP8mzC
# Ym+bGDeTUwDDimzDqaDwJmin+IVQH81rpruvQHQUzLNGoyw7kwBTI+siHHT8fSQP
# tnziAM4rtEEXczcOxUU3BiRy7eiFrCuKaYHNf6ZDDQ2Lwh603Yik3XkduBO5N3NG
# 2MHw2ZNh9Q0RQAXh8t5QJgVFKSSYsl/qa99egSwt8y7gE84UM9t8DkS46+haUp+x
# DDDrgD2goaHBxHKX8tIU8sPZnLlmQwFHO9SxZX2PeZ0AzWEtR1WCs+W62N4dlaBY
# SRRkA/flA9BxAeDznmVxNBOIIDIxvgCKT/26eFe3GMBvTAsnMVN32KGekmhGiUtR
# CUceePFzAKCEc6+TbFa1hAd3r0odQqnaAE1dt2Q7QtxoFdB4gCRMYHxC9DakqznU
# OjaV9tsUMeWZ+pd85Bmsu4pWox84dqGCGN8wghjbBgorBgEEAYI3AwMBMYIYyzCC
# GMcGCSqGSIb3DQEHAqCCGLgwghi0AgEDMQ8wDQYJYIZIAWUDBAICBQAwggEEBgsq
# hkiG9w0BCRABBKCB9ASB8TCB7gIBAQYKKwYBBAGyMQIBATBBMA0GCWCGSAFlAwQC
# AgUABDCApFUZ4EzSnQZKOeOyag/7a05CX45ZWW5s+6wkF9dfrL43ocgR5IeoNzDD
# no3Y+IwCFQDCRIE0yALyQgEU0U99/FsNw5uPVxgPMjAyNDEwMTYxMTQyMTJaoHKk
# cDBuMQswCQYDVQQGEwJHQjETMBEGA1UECBMKTWFuY2hlc3RlcjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMTAwLgYDVQQDEydTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFNpZ25lciBSMzWgghL/MIIGXTCCBMWgAwIBAgIQOlJqLITOVeYdZfzM
# EtjpiTANBgkqhkiG9w0BAQwFADBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2Vj
# dGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1w
# aW5nIENBIFIzNjAeFw0yNDAxMTUwMDAwMDBaFw0zNTA0MTQyMzU5NTlaMG4xCzAJ
# BgNVBAYTAkdCMRMwEQYDVQQIEwpNYW5jaGVzdGVyMRgwFgYDVQQKEw9TZWN0aWdv
# IExpbWl0ZWQxMDAuBgNVBAMTJ1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcg
# U2lnbmVyIFIzNTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAI3RZ/TB
# SJu9/ThJOk1hgZvD2NxFpWEENo0GnuOYloD11BlbmKCGtcY0xiMrsN7LlEgcyosh
# tP3P2J/vneZhuiMmspY7hk/Q3l0FPZPBllo9vwT6GpoNnxXLZz7HU2ITBsTNOs9f
# hbdAWr/Mm8MNtYov32osvjYYlDNfefnBajrQqSV8Wf5ZvbaY5lZhKqQJUaXxpi4T
# XZKohLgxU7g9RrFd477j7jxilCU2ptz+d1OCzNFAsXgyPEM+NEMPUz2q+ktNlxMZ
# XPF9WLIhOhE3E8/oNSJkNTqhcBGsbDI/1qCU9fBhuSojZ0u5/1+IjMG6AINyI6XL
# xM8OAGQmaMB8gs2IZxUTOD7jTFR2HE1xoL7qvSO4+JHtvNceHu//dGeVm5Pdkay3
# Et+YTt9EwAXBsd0PPmC0cuqNJNcOI0XnwjE+2+Zk8bauVz5ir7YHz7mlj5Bmf7W8
# SJ8jQwO2IDoHHFC46ePg+eoNors0QrC0PWnOgDeMkW6gmLBtq3CEOSDU8iNicwNs
# Nb7ABz0W1E3qlSw7jTmNoGCKCgVkLD2FaMs2qAVVOjuUxvmtWMn1pIFVUvZ1yrPI
# VbYt1aTld2nrmh544Auh3tgggy/WluoLXlHtAJgvFwrVsKXj8ekFt0TmaPL0lHvQ
# Ee5jHbufhc05lvCtdwbfBl/2ARSTuy1s8CgFAgMBAAGjggGOMIIBijAfBgNVHSME
# GDAWgBRfWO1MMXqiYUKNUoC6s2GXGaIymzAdBgNVHQ4EFgQUaO+kMklptlI4HepD
# OSz0FGqeDIUwDgYDVR0PAQH/BAQDAgbAMAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/
# BAwwCgYIKwYBBQUHAwgwSgYDVR0gBEMwQTA1BgwrBgEEAbIxAQIBAwgwJTAjBggr
# BgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdvLmNvbS9DUFMwCAYGZ4EMAQQCMEoGA1Ud
# HwRDMEEwP6A9oDuGOWh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1Ymxp
# Y1RpbWVTdGFtcGluZ0NBUjM2LmNybDB6BggrBgEFBQcBAQRuMGwwRQYIKwYBBQUH
# MAKGOWh0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFt
# cGluZ0NBUjM2LmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5j
# b20wDQYJKoZIhvcNAQEMBQADggGBALDcLsn6TzZMii/2yU/V7xhPH58Oxr/+EnrZ
# jpIyvYTz2u/zbL+fzB7lbrPml8ERajOVbudan6x08J1RMXD9hByq+yEfpv1G+z2p
# mnln5XucfA9MfzLMrCArNNMbUjVcRcsAr18eeZeloN5V4jwrovDeLOdZl0tB7fOX
# 5F6N2rmXaNTuJR8yS2F+EWaL5VVg+RH8FelXtRvVDLJZ5uqSNIckdGa/eUFhtDKT
# Tz9LtOUh46v2JD5Q3nt8mDhAjTKp2fo/KJ6FLWdKAvApGzjpPwDqFeJKf+kJdoBK
# d2zQuwzk5Wgph9uA46VYK8p/BTJJahKCuGdyKFIFfEfakC4NXa+vwY4IRp49lzQP
# Lo7WticqMaaqb8hE2QmCFIyLOvWIg4837bd+60FcCGbHwmL/g1ObIf0rRS9ceK4D
# Y9rfBnHFH2v1d4hRVvZXyCVlrL7ZQuVzjjkLMK9VJlXTVkHpuC8K5S4HHTv2AJx6
# mOdkMJwS4gLlJ7gXrIVpnxG+aIniGDCCBhQwggP8oAMCAQICEHojrtpTaZYPkcg+
# XPTH4z8wDQYJKoZIhvcNAQEMBQAwVzELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1Nl
# Y3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFt
# cGluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5NTlaMFUx
# CzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMT
# I1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgQ0EgUjM2MIIBojANBgkqhkiG
# 9w0BAQEFAAOCAY8AMIIBigKCAYEAzZjYQ0GrboIr7PYzfiY05ImM0+8iEoBUPu8m
# r4wOgYPjoiIz5vzf7d5wu8GFK1JWN5hciN9rdqOhbdxLcSVwnOTJmUGfAMQm4eXO
# ls3iQwfapEFWuOsYmBKXPNSpwZAFoLGl5y1EaGGc5LByM8wjcbSF52/Z42YaJRsP
# XY545E3QAPN2mxDh0OLozhiGgYT1xtjXVfEzYBVmfQaI5QL35cTTAjsJAp85R+KA
# sOfuL9Z7LFnjdcuPkZWjssMETFIueH69rxbFOUD64G+rUo7xFIdRAuDNvWBsv0iG
# DPGaR2nZlY24tz5fISYk1sPY4gir99aXAGnoo0vX3Okew4MsiyBn5ZnUDMKzUcQr
# pVavGacrIkmDYu/bcOUR1mVBIZ0X7P4bKf38JF7Mp7tY3LFF/h7hvBS2tgTYXlD7
# TnIMPrxyXCfB5yQq3FFoXRXM3/DvqQ4shoVWF/mwwz9xoRku05iphp22fTfjKRIV
# pm4gFT24JKspEpM8mFa9eTgKWWCvAgMBAAGjggFcMIIBWDAfBgNVHSMEGDAWgBT2
# d2rdP/0BE/8WoWyCAi/QCj0UJTAdBgNVHQ4EFgQUX1jtTDF6omFCjVKAurNhlxmi
# MpswDgYDVR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAww
# CgYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRVHSAAMEwGA1UdHwRFMEMwQaA/oD2G
# O2h0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGlu
# Z1Jvb3RSNDYuY3JsMHwGCCsGAQUFBwEBBHAwbjBHBggrBgEFBQcwAoY7aHR0cDov
# L2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1waW5nUm9vdFI0
# Ni5wN2MwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqG
# SIb3DQEBDAUAA4ICAQAS13sgrQ41WAyegR0lWP1MLWd0r8diJiH2VVRpxqFGhnZb
# aF+IQ7JATGceTWOS+kgnMAzGYRzpm8jIcjlSQ8JtcqymKhgx1s6cFZBSfvfeoyig
# F8iCGlH+SVSo3HHr98NepjSFJTU5KSRKK+3nVSWYkSVQgJlgGh3MPcz9IWN4I/n1
# qfDGzqHCPWZ+/Mb5vVyhgaeqxLPbBIqv6cM74Nvyo1xNsllECJJrOvsrJQkajVz4
# xJwZ8blAdX5umzwFfk7K/0K3fpjgiXpqNOpXaJ+KSRW0HdE0FSDC7+ZKJJSJx78m
# n+rwEyT+A3z7Ss0gT5CpTrcmhUwIw9jbvnYuYRKxFVWjKklW3z83epDVzoWJttxF
# pujdrNmRwh1YZVIB2guAAjEQoF42H0BA7WBCueHVMDyV1e4nM9K4As7PVSNvQ8LI
# 1WRaTuGSFUd9y8F8jw22BZC6mJoB40d7SlZIYfaildlgpgbgtu6SDsek2L8qomG5
# 7Yp5qTqof0DwJ4Q4HsShvRl/59T4IJBovRwmqWafH0cIPEX7cEttS5+tXrgRtMjj
# TOp6A9l0D6xcKZtxnLqiTH9KPCy6xZEi0UDcMTww5Fl4VvoGbMG2oonuX3f1tsoH
# LaO/Fwkj3xVr3lDkmeUqivebQTvGkx5hGuJaSVQ+x60xJ/Y29RBr8Tm9XJ59AjCC
# BoIwggRqoAMCAQICEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEMBQAwgYgx
# CzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJz
# ZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQD
# EyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTIxMDMy
# MjAwMDAwMFoXDTM4MDExODIzNTk1OVowVzELMAkGA1UEBhMCR0IxGDAWBgNVBAoT
# D1NlY3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMgVGltZSBT
# dGFtcGluZyBSb290IFI0NjCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIB
# AIid2LlFZ50d3ei5JoGaVFTAfEkFm8xaFQ/ZlBBEtEFAgXcUmanU5HYsyAhTXiDQ
# kiUvpVdYqZ1uYoZEMgtHES1l1Cc6HaqZzEbOOp6YiTx63ywTon434aXVydmhx7Dx
# 4IBrAou7hNGsKioIBPy5GMN7KmgYmuu4f92sKKjbxqohUSfjk1mJlAjthgF7Hjx4
# vvyVDQGsd5KarLW5d73E3ThobSkob2SL48LpUR/O627pDchxll+bTSv1gASn/hp6
# IuHJorEu6EopoB1CNFp/+HpTXeNARXUmdRMKbnXWflq+/g36NJXB35ZvxQw6zid6
# 1qmrlD/IbKJA6COw/8lFSPQwBP1ityZdwuCysCKZ9ZjczMqbUcLFyq6KdOpuzVDR
# 3ZUwxDKL1wCAxgL2Mpz7eZbrb/JWXiOcNzDpQsmwGQ6Stw8tTCqPumhLRPb7YkzM
# 8/6NnWH3T9ClmcGSF22LEyJYNWCHrQqYubNeKolzqUbCqhSqmr/UdUeb49zYHr7A
# LL8bAJyPDmubNqMtuaobKASBqP84uhqcRY/pjnYd+V5/dcu9ieERjiRKKsxCG1t6
# tG9oj7liwPddXEcYGOUiWLm742st50jGwTzxbMpepmOP1mLnJskvZaN5e45NuzAH
# teORlsSuDt5t4BBRCJL+5EZnnw0ezntk9R8QJyAkL6/bAgMBAAGjggEWMIIBEjAf
# BgNVHSMEGDAWgBRTeb9aqitKz1SA4dibwJ3ysgNmyzAdBgNVHQ4EFgQU9ndq3T/9
# ARP/FqFsggIv0Ao9FCUwDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8w
# EwYDVR0lBAwwCgYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRVHSAAMFAGA1UdHwRJ
# MEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FD
# ZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDA1BggrBgEFBQcBAQQpMCcwJQYIKwYB
# BQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcNAQEMBQAD
# ggIBAA6+ZUHtaES45aHF1BGH5Lc7JYzrftrIF5Ht2PFDxKKFOct/awAEWgHQMVHo
# l9ZLSyd/pYMbaC0IZ+XBW9xhdkkmUV/KbUOiL7g98M/yzRyqUOZ1/IY7Ay0YbMni
# IibJrPcgFp73WDnRDKtVutShPSZQZAdtFwXnuiWl8eFARK3PmLqEm9UsVX+55DbV
# Iz33Mbhba0HUTEYv3yJ1fwKGxPBsP/MgTECimh7eXomvMm0/GPxX2uhwCcs/YLxD
# nBdVVlxvDjHjO1cuwbOpkiJGHmLXXVNbsdXUC2xBrq9fLrfe8IBsA4hopwsCj8hT
# uwKXJlSTrZcPRVSccP5i9U28gZ7OMzoJGlxZ5384OKm0r568Mo9TYrqzKeKZgFo0
# fj2/0iHbj55hc20jfxvK3mQi+H7xpbzxZOFGm/yVQkpo+ffv5gdhp+hv1GDsvJOt
# JinJmgGbBFZIThbqI+MHvAmMmkfb3fTxmSkop2mSJL1Y2x/955S29Gu0gSJIkc3z
# 30vU/iXrMpWx2tS7UVfVP+5tKuzGtgkP7d/doqDrLF1u6Ci3TpjAZdeLLlRQZm86
# 7eVeXED58LXd1Dk6UvaAhvmWYXoiLz4JA5gPBcz7J311uahxCweNxE+xxxR3kT0W
# KzASo5G/PyDez6NHdIUKBeE3jDPs2ACc6CkJ1Sji4PKWVT0/MYIEkTCCBI0CAQEw
# aTBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYD
# VQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNgIQOlJqLITO
# VeYdZfzMEtjpiTANBglghkgBZQMEAgIFAKCCAfkwGgYJKoZIhvcNAQkDMQ0GCyqG
# SIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNDEwMTYxMTQyMTJaMD8GCSqGSIb3
# DQEJBDEyBDCJ8fV2rAJUhoNXfYxtkLpLQ+jojWXuE7FBXxnvlt4KGKpSaFwTdyHl
# GP/ClKJgNqswggF6BgsqhkiG9w0BCRACDDGCAWkwggFlMIIBYTAWBBT4YJgZpvuI
# LPfoUpfyoRlSGhZ3XzCBhwQUxq5U5HiG8Xw9VRJIjGnDSnr5wt0wbzBbpFkwVzEL
# MAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEuMCwGA1UEAxMl
# U2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBSb290IFI0NgIQeiOu2lNplg+R
# yD5c9MfjPzCBvAQUhT1jLZOCgmF80JA1xJHeksFC2scwgaMwgY6kgYswgYgxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkg
# Q2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQDEyVV
# U0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5AhA2wrC9fBs656Oz
# 3TbLyXVoMA0GCSqGSIb3DQEBAQUABIICADTs2bCA+OjtZ2cf8QVQiS2x9a8G4oER
# NKjJkk9f6gWs3zlspRBXpamugSLpk5jUdo/PfeN6OnJWQQyk6ukRowxMYySCGp/t
# tQfWjkubZ4dH73eB9xk2KwrqIKjGySiIGY3541mIAAeQyOWbWWFJN9D9uJSnJdUz
# yWMcmucUlijNkVFKLMnloi/IkQ27fFtEafBtqy4jnjrjMRBIfvv2fICjAzyKHmiE
# y5BiJ7+jo75wSIAFgWdq7LYbJpFzc0X93FPd2+tFabjlkfJu/UVQaIx/N45LBGSr
# LdCTC1RnWt0BdnpMMHm6M3rZ7d0M68nZHCImQxHmgLfsFtjLs0O+G4M06geNapZs
# EBknh0dAl7OziNJLP77qWUnCRShtDwcD5iT6Fua4OZOr57DonmEj/OKh9wH2lIOE
# 4pOfl/hUT19rDQSZ77orFl4Y0FwW76gzZ4HnFKEnXT7EyDK5HGfJJ7Il8ZLsUkuS
# PgbIIoVPOS/WjwBfUJgU6k+Bb2w/9GaoqEKLeEao2Kx1mVea3JHKlrWVqj9OrzOF
# vOZnDvLg33oKgm/aWNAGPx8FJ7s+fLAQWKEprBBCGnOsoFk7vMih44MZd8FT8xnY
# DX99WHWUgkX+VFloLfn+ezncxfLQaoWtnbj0yKEtR0SM+DQDP4emAYRntrgfP4ka
# 0GhkooJO6rep
# SIG # End signature block
