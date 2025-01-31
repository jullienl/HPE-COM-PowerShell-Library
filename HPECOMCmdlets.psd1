#
# Module manifest for module 'HPECOMCmdlets'
#
# Generated by: Lionel Jullien
#
# Generated on: 1/31/2025
#

@{

# Script module or binary module file associated with this manifest.
RootModule = 'HPECOMCmdlets.psm1'

# Version number of this module.
ModuleVersion = '1.0.11'

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
               'Add-HPEGLDeviceToService', 'Add-HPEGLRoleToUser',
               'Add-HPEGLSubscriptionToDevice', 'Connect-HPEGL',
               'Connect-HPEGLDeviceComputeiLOtoCOM', 'Connect-HPEGLWorkspace',
               'Disable-HPECOMEmailNotificationPolicy',
               'Disable-HPECOMIloIgnoreRiskSetting',
               'Disable-HPECOMServerAutoiLOFirmwareUpdate', 'Disable-HPEGLDevice',
               'Disconnect-HPEGL', 'Enable-HPECOMEmailNotificationPolicy',
               'Enable-HPECOMIloIgnoreRiskSetting',
               'Enable-HPECOMServerAutoiLOFirmwareUpdate', 'Enable-HPEGLDevice',
               'Get-HPECOMActivity', 'Get-HPECOMAppliance',
               'Get-HPECOMApplianceFirmwareBundle',
               'Get-HPECOMEmailNotificationPolicy', 'Get-HPECOMExternalService',
               'Get-HPECOMFilter', 'Get-HPECOMFirmwareBundle', 'Get-HPECOMGroup',
               'Get-HPECOMGroupFirmwareCompliance', 'Get-HPECOMIloSecuritySatus',
               'Get-HPECOMJob', 'Get-HPECOMJobTemplate',
               'Get-HPECOMMetricsConfiguration', 'Get-HPECOMReport',
               'Get-HPECOMSchedule', 'Get-HPECOMServer',
               'Get-HPECOMServerActivationKey', 'Get-HPECOMServeriLOSSO',
               'Get-HPECOMServerInventory', 'Get-HPECOMSetting',
               'Get-HPECOMSustainabilityReport', 'Get-HPECOMWebhook',
               'Get-HPEGLAPIcredential', 'Get-HPEGLAuditLog', 'Get-HPEGLdevice',
               'Get-HPEGLDeviceAutoReassignSubscription',
               'Get-HPEGLDeviceAutoSubscription', 'Get-HPEGLJWTDetails',
               'Get-HPEGLLocation', 'Get-HPEGLRegion',
               'Get-HPEGLResourceRestrictionPolicy', 'Get-HPEGLRole',
               'Get-HPEGLService',
               'Get-HPEGLServiceResourceRestrictionPolicyFilter',
               'Get-HPEGLSubscription', 'Get-HPEGLUser',
               'Get-HPEGLUserAccountDetails', 'Get-HPEGLUserPreference',
               'Get-HPEGLUserRole', 'Get-HPEGLWorkspace',
               'Get-HPEGLWorkspaceSAMLSSODomain',
               'Invoke-HPECOMGroupBiosConfiguration',
               'Invoke-HPECOMGroupExternalStorageComplianceCheck',
               'Invoke-HPECOMGroupExternalStorageConfiguration',
               'Invoke-HPECOMGroupFirmwareComplianceCheck',
               'Invoke-HPECOMGroupInternalStorageConfiguration',
               'Invoke-HPECOMGroupOSInstallation', 'Invoke-HPECOMWebRequest',
               'Invoke-HPEGLWebRequest', 'New-HPECOMAppliance',
               'New-HPECOMExternalService', 'New-HPECOMFilter', 'New-HPECOMGroup',
               'New-HPECOMServerActivationKey', 'New-HPECOMServerInventory',
               'New-HPECOMSettingServerBios',
               'New-HPECOMSettingServerExternalStorage',
               'New-HPECOMSettingServerFirmware',
               'New-HPECOMSettingServerInternalStorage',
               'New-HPECOMSettingServerOSImage', 'New-HPECOMSustainabilityReport',
               'New-HPECOMWebhook', 'New-HPEGLAPIcredential', 'New-HPEGLLocation',
               'New-HPEGLResourceRestrictionPolicy', 'New-HPEGLService',
               'New-HPEGLSubscription', 'New-HPEGLWorkspace',
               'New-HPEGLWorkspaceSAMLSSODomain', 'Remove-HPECOMAppliance',
               'Remove-HPECOMExternalService', 'Remove-HPECOMFilter',
               'Remove-HPECOMGroup', 'Remove-HPECOMOneViewServerLocation',
               'Remove-HPECOMSchedule', 'Remove-HPECOMServerActivationKey',
               'Remove-HPECOMServerFromGroup', 'Remove-HPECOMSetting',
               'Remove-HPECOMWebhook', 'Remove-HPEGLAPICredential',
               'Remove-HPEGLDeviceAutoReassignSubscription',
               'Remove-HPEGLDeviceAutoSubscription',
               'Remove-HPEGLDeviceFromService', 'Remove-HPEGLDeviceLocation',
               'Remove-HPEGLDeviceTagFromDevice', 'Remove-HPEGLLocation',
               'Remove-HPEGLResourceRestrictionPolicy', 'Remove-HPEGLRoleFromUser',
               'Remove-HPEGLService', 'Remove-HPEGLSubscription',
               'Remove-HPEGLSubscriptionFromDevice', 'Remove-HPEGLUser',
               'Remove-HPEGLWorkspaceSAMLSSODomain', 'Restart-HPECOMserver',
               'Send-HPECOMWebhookTest', 'Send-HPEGLUserInvitation',
               'Send-HPEGLWorkspaceSAMLSSODomainNotifications',
               'Set-HPECOMExternalService', 'Set-HPECOMFilter', 'Set-HPECOMGroup',
               'Set-HPECOMOneViewServerLocation', 'Set-HPECOMSchedule',
               'Set-HPECOMSettingServerBios',
               'Set-HPECOMSettingServerExternalStorage',
               'Set-HPECOMSettingServerFirmware',
               'Set-HPECOMSettingServerInternalStorage',
               'Set-HPECOMSettingServerOSImage', 'Set-HPECOMWebhook',
               'Set-HPEGLDeviceAutoReassignSubscription',
               'Set-HPEGLDeviceAutoSubscription', 'Set-HPEGLDeviceLocation',
               'Set-HPEGLLocation', 'Set-HPEGLUserAccountDetails',
               'Set-HPEGLUserAccountPassword', 'Set-HPEGLUserPreference',
               'Set-HPEGLWorkspace', 'Set-HPEGLWorkspaceSAMLSSODomain',
               'Start-HPECOMserver', 'Stop-HPECOMGroupFirmware', 'Stop-HPECOMserver',
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
- Removed the delete API credential operation in Remove-HPEGLService. Now, when a service is deleted, all associated API credentials are also deleted.

- Introduced new cmdlets:
  - Get-HPEGLWorkspaceSAMLSSODomain
  - New-HPEGLWorkspaceSAMLSSODomain
  - Set-HPEGLWorkspaceSAMLSSODomain
  - Remove-HPEGLWorkspaceSAMLSSODomain
  - Send-HPEGLWorkspaceSAMLSSODomainNotifications (sends notifications to all users of a domain)
  - Get-HPECOMServeriLOSSO (generates an iLO SSO object that can be used with the HPEiLOCmdlets module to connect to an iLO or to create native RedFish calls)

- Updated Set-HPEGLUserAccountPassword to align with the new API endpoint for changing passwords.

- Added generation of access token v1.2 during the login process to support future v2 workspace methods.

- Enhanced the onboarding experience in Connect-HPEGLDeviceComputeiLOtoCOM and added tests to ensure that the iLOs are reachable from the system where the cmdlet is executed.

- Fixed issues with job activity messages:
  - Corrected activity message tracking in Get-HPECOMActivity, as the source resourceUri is not always the same as the job resourceUri.
  - Corrected activity message tracking in Wait-HPECOMJobComplete.
  - Fixed New-HPECOMServerInventory to generate activity messages properly.

- Fixed an issue with the Get-HPECOMActivity cmdlet that was not returning activities correctly when filtering on a specific job.
  - Now, using @{Name=CZ2311004H; Region=eu-central; Status=Complete; Details=Server auto iLO firmware successfully enabled in eu-central region; Exception=; PSObject.TypeNames=System.Object[]} | Get-HPECOMActivity will return the activities of the job.

- Enhanced Invoked-HPEGLWebrequest and Invoked-HPECOMWebrequest to correctly return the response error message when the response is not successful.

- Added support for Ubuntu in New-HPECOMSettingServerOSImage.

- Implemented several other minor improvements.
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
# MIItlAYJKoZIhvcNAQcCoIIthTCCLYECAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBIFYArOArz6PBE
# cYZ/xFQ0vUjU1GRU80cog9QG0SZ786CCEXYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# Syatatvx157YK9hlcPmVoa1oDE5/L9Uo2bC5a4CH2Rwxght0MIIbcAIBATBpMFQx
# CzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNVBAMT
# IlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYCEQDzfDeB/ajwfQYd
# ZdJTJuKyMA0GCWCGSAFlAwQCAQUAoHwwEAYKKwYBBAGCNwIBDDECMAAwGQYJKoZI
# hvcNAQkDMQwGCisGAQQBgjcCAQQwHAYKKwYBBAGCNwIBCzEOMAwGCisGAQQBgjcC
# ARUwLwYJKoZIhvcNAQkEMSIEIIsaddpZGBK39uojfrfkvegDX+Ub+XpGyHf8puQ7
# Nr/JMA0GCSqGSIb3DQEBAQUABIIBgBR0czpzYpRZmisC3TYmEo2HoEzOV2YLuLHj
# nnBrjjn7f2peTmpd/v880bcFmfX8ldufaKpeQ0my5RnFybht8+AZQO8F11GMHbVA
# cDPGXTvLLybFT43+dugZ4GDv7HX3bMJM4WNeMzmN/5aE4NN78AtdL5VklU5OSa/m
# HfnhGw28kjovDOm3w+bjcFlJm1SYIn7/1w8wT4rpDodtx2OYflQirUlKsxDfkPUR
# U9IU4BQX64iPNAcHXQDISKXTpBXJ7QLuPL/JggiCMKxiECCemoQoLC7l50JSTv2E
# emaGiHyxjrxmrXkvf/DyDSibE0APn//Ywl1tln6ZCnSSWcBtb1tJGg+lZ7CqKur3
# wf3fml5EfVfNAYtkELb5PH4OYyx2DEoG9BFlfwu/GfjZNjHtvlYvSyDz/QGkTAZc
# NsuMLV512QZypgFcMcBM4daX7IEUhkP/xTd/+L3Nw4WWrW0q2XokVaGtW1Xx4P+r
# hsfarmiP9AGguBLPU80bwb2RXK2XaaGCGN4wghjaBgorBgEEAYI3AwMBMYIYyjCC
# GMYGCSqGSIb3DQEHAqCCGLcwghizAgEDMQ8wDQYJYIZIAWUDBAICBQAwggEDBgsq
# hkiG9w0BCRABBKCB8wSB8DCB7QIBAQYKKwYBBAGyMQIBATBBMA0GCWCGSAFlAwQC
# AgUABDDPeprkCGeThTg3K/KbwuoYyv77JM8RY92yAA4M6IsJpxiEbH/40h3rYF11
# lxd7Pa0CFEIrq9d2ZAq+kGNW35PGP/yW15KcGA8yMDI1MDEzMTE2MzEzNlqgcqRw
# MG4xCzAJBgNVBAYTAkdCMRMwEQYDVQQIEwpNYW5jaGVzdGVyMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMTJ1NlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgU2lnbmVyIFIzNaCCEv8wggZdMIIExaADAgECAhA6UmoshM5V5h1l/MwS
# 2OmJMA0GCSqGSIb3DQEBDAUAMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0
# aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBp
# bmcgQ0EgUjM2MB4XDTI0MDExNTAwMDAwMFoXDTM1MDQxNDIzNTk1OVowbjELMAkG
# A1UEBhMCR0IxEzARBgNVBAgTCk1hbmNoZXN0ZXIxGDAWBgNVBAoTD1NlY3RpZ28g
# TGltaXRlZDEwMC4GA1UEAxMnU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBT
# aWduZXIgUjM1MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAjdFn9MFI
# m739OEk6TWGBm8PY3EWlYQQ2jQae45iWgPXUGVuYoIa1xjTGIyuw3suUSBzKiyG0
# /c/Yn++d5mG6IyayljuGT9DeXQU9k8GWWj2/BPoamg2fFctnPsdTYhMGxM06z1+F
# t0Bav8ybww21ii/faiy+NhiUM195+cFqOtCpJXxZ/lm9tpjmVmEqpAlRpfGmLhNd
# kqiEuDFTuD1GsV3jvuPuPGKUJTam3P53U4LM0UCxeDI8Qz40Qw9TPar6S02XExlc
# 8X1YsiE6ETcTz+g1ImQ1OqFwEaxsMj/WoJT18GG5KiNnS7n/X4iMwboAg3IjpcvE
# zw4AZCZowHyCzYhnFRM4PuNMVHYcTXGgvuq9I7j4ke281x4e7/90Z5Wbk92RrLcS
# 35hO30TABcGx3Q8+YLRy6o0k1w4jRefCMT7b5mTxtq5XPmKvtgfPuaWPkGZ/tbxI
# nyNDA7YgOgccULjp4+D56g2iuzRCsLQ9ac6AN4yRbqCYsG2rcIQ5INTyI2JzA2w1
# vsAHPRbUTeqVLDuNOY2gYIoKBWQsPYVoyzaoBVU6O5TG+a1YyfWkgVVS9nXKs8hV
# ti3VpOV3aeuaHnjgC6He2CCDL9aW6gteUe0AmC8XCtWwpePx6QW3ROZo8vSUe9AR
# 7mMdu5+FzTmW8K13Bt8GX/YBFJO7LWzwKAUCAwEAAaOCAY4wggGKMB8GA1UdIwQY
# MBaAFF9Y7UwxeqJhQo1SgLqzYZcZojKbMB0GA1UdDgQWBBRo76QySWm2Ujgd6kM5
# LPQUap4MhTAOBgNVHQ8BAf8EBAMCBsAwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8E
# DDAKBggrBgEFBQcDCDBKBgNVHSAEQzBBMDUGDCsGAQQBsjEBAgEDCDAlMCMGCCsG
# AQUFBwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAIBgZngQwBBAIwSgYDVR0f
# BEMwQTA/oD2gO4Y5aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGlj
# VGltZVN0YW1waW5nQ0FSMzYuY3JsMHoGCCsGAQUFBwEBBG4wbDBFBggrBgEFBQcw
# AoY5aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1w
# aW5nQ0FSMzYuY3J0MCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdvLmNv
# bTANBgkqhkiG9w0BAQwFAAOCAYEAsNwuyfpPNkyKL/bJT9XvGE8fnw7Gv/4SetmO
# kjK9hPPa7/Nsv5/MHuVus+aXwRFqM5Vu51qfrHTwnVExcP2EHKr7IR+m/Ub7Pama
# eWfle5x8D0x/MsysICs00xtSNVxFywCvXx55l6Wg3lXiPCui8N4s51mXS0Ht85fk
# Xo3auZdo1O4lHzJLYX4RZovlVWD5EfwV6Ve1G9UMslnm6pI0hyR0Zr95QWG0MpNP
# P0u05SHjq/YkPlDee3yYOECNMqnZ+j8onoUtZ0oC8CkbOOk/AOoV4kp/6Ql2gEp3
# bNC7DOTlaCmH24DjpVgryn8FMklqEoK4Z3IoUgV8R9qQLg1dr6/BjghGnj2XNA8u
# jta2JyoxpqpvyETZCYIUjIs69YiDjzftt37rQVwIZsfCYv+DU5sh/StFL1x4rgNj
# 2t8GccUfa/V3iFFW9lfIJWWsvtlC5XOOOQswr1UmVdNWQem4LwrlLgcdO/YAnHqY
# 52QwnBLiAuUnuBeshWmfEb5oieIYMIIGFDCCA/ygAwIBAgIQeiOu2lNplg+RyD5c
# 9MfjPzANBgkqhkiG9w0BAQwFADBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2Vj
# dGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1w
# aW5nIFJvb3QgUjQ2MB4XDTIxMDMyMjAwMDAwMFoXDTM2MDMyMTIzNTk1OVowVTEL
# MAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMj
# U2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBDQSBSMzYwggGiMA0GCSqGSIb3
# DQEBAQUAA4IBjwAwggGKAoIBgQDNmNhDQatugivs9jN+JjTkiYzT7yISgFQ+7yav
# jA6Bg+OiIjPm/N/t3nC7wYUrUlY3mFyI32t2o6Ft3EtxJXCc5MmZQZ8AxCbh5c6W
# zeJDB9qkQVa46xiYEpc81KnBkAWgsaXnLURoYZzksHIzzCNxtIXnb9njZholGw9d
# jnjkTdAA83abEOHQ4ujOGIaBhPXG2NdV8TNgFWZ9BojlAvflxNMCOwkCnzlH4oCw
# 5+4v1nssWeN1y4+RlaOywwRMUi54fr2vFsU5QPrgb6tSjvEUh1EC4M29YGy/SIYM
# 8ZpHadmVjbi3Pl8hJiTWw9jiCKv31pcAaeijS9fc6R7DgyyLIGflmdQMwrNRxCul
# Vq8ZpysiSYNi79tw5RHWZUEhnRfs/hsp/fwkXsynu1jcsUX+HuG8FLa2BNheUPtO
# cgw+vHJcJ8HnJCrcUWhdFczf8O+pDiyGhVYX+bDDP3GhGS7TmKmGnbZ9N+MpEhWm
# biAVPbgkqykSkzyYVr15OApZYK8CAwEAAaOCAVwwggFYMB8GA1UdIwQYMBaAFPZ3
# at0//QET/xahbIICL9AKPRQlMB0GA1UdDgQWBBRfWO1MMXqiYUKNUoC6s2GXGaIy
# mzAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAK
# BggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAwTAYDVR0fBEUwQzBBoD+gPYY7
# aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1waW5n
# Um9vdFI0Ni5jcmwwfAYIKwYBBQUHAQEEcDBuMEcGCCsGAQUFBzAChjtodHRwOi8v
# Y3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdSb290UjQ2
# LnA3YzAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZI
# hvcNAQEMBQADggIBABLXeyCtDjVYDJ6BHSVY/UwtZ3Svx2ImIfZVVGnGoUaGdlto
# X4hDskBMZx5NY5L6SCcwDMZhHOmbyMhyOVJDwm1yrKYqGDHWzpwVkFJ+996jKKAX
# yIIaUf5JVKjccev3w16mNIUlNTkpJEor7edVJZiRJVCAmWAaHcw9zP0hY3gj+fWp
# 8MbOocI9Zn78xvm9XKGBp6rEs9sEiq/pwzvg2/KjXE2yWUQIkms6+yslCRqNXPjE
# nBnxuUB1fm6bPAV+Tsr/Qrd+mOCJemo06ldon4pJFbQd0TQVIMLv5koklInHvyaf
# 6vATJP4DfPtKzSBPkKlOtyaFTAjD2Nu+di5hErEVVaMqSVbfPzd6kNXOhYm23EWm
# 6N2s2ZHCHVhlUgHaC4ACMRCgXjYfQEDtYEK54dUwPJXV7icz0rgCzs9VI29DwsjV
# ZFpO4ZIVR33LwXyPDbYFkLqYmgHjR3tKVkhh9qKV2WCmBuC27pIOx6TYvyqiYbnt
# inmpOqh/QPAnhDgexKG9GX/n1PggkGi9HCapZp8fRwg8RftwS21Ln61euBG0yONM
# 6noD2XQPrFwpm3GcuqJMf0o8LLrFkSLRQNwxPDDkWXhW+gZswbaiie5fd/W2ygct
# o78XCSPfFWveUOSZ5SqK95tBO8aTHmEa4lpJVD7HrTEn9jb1EGvxOb1cnn0CMIIG
# gjCCBGqgAwIBAgIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQwFADCBiDEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNl
# eSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMT
# JVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMjEwMzIy
# MDAwMDAwWhcNMzgwMTE4MjM1OTU5WjBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA
# iJ3YuUVnnR3d6LkmgZpUVMB8SQWbzFoVD9mUEES0QUCBdxSZqdTkdizICFNeINCS
# JS+lV1ipnW5ihkQyC0cRLWXUJzodqpnMRs46npiJPHrfLBOifjfhpdXJ2aHHsPHg
# gGsCi7uE0awqKggE/LkYw3sqaBia67h/3awoqNvGqiFRJ+OTWYmUCO2GAXsePHi+
# /JUNAax3kpqstbl3vcTdOGhtKShvZIvjwulRH87rbukNyHGWX5tNK/WABKf+Gnoi
# 4cmisS7oSimgHUI0Wn/4elNd40BFdSZ1EwpuddZ+Wr7+Dfo0lcHflm/FDDrOJ3rW
# qauUP8hsokDoI7D/yUVI9DAE/WK3Jl3C4LKwIpn1mNzMyptRwsXKrop06m7NUNHd
# lTDEMovXAIDGAvYynPt5lutv8lZeI5w3MOlCybAZDpK3Dy1MKo+6aEtE9vtiTMzz
# /o2dYfdP0KWZwZIXbYsTIlg1YIetCpi5s14qiXOpRsKqFKqav9R1R5vj3NgevsAs
# vxsAnI8Oa5s2oy25qhsoBIGo/zi6GpxFj+mOdh35Xn91y72J4RGOJEoqzEIbW3q0
# b2iPuWLA911cRxgY5SJYubvjay3nSMbBPPFsyl6mY4/WYucmyS9lo3l7jk27MAe1
# 45GWxK4O3m3gEFEIkv7kRmefDR7Oe2T1HxAnICQvr9sCAwEAAaOCARYwggESMB8G
# A1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQWBBT2d2rdP/0B
# E/8WoWyCAi/QCj0UJTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAT
# BgNVHSUEDDAKBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAwUAYDVR0fBEkw
# RzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJUcnVzdFJTQUNl
# cnRpZmljYXRpb25BdXRob3JpdHkuY3JsMDUGCCsGAQUFBwEBBCkwJzAlBggrBgEF
# BQcwAYYZaHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG9w0BAQwFAAOC
# AgEADr5lQe1oRLjlocXUEYfktzsljOt+2sgXke3Y8UPEooU5y39rAARaAdAxUeiX
# 1ktLJ3+lgxtoLQhn5cFb3GF2SSZRX8ptQ6IvuD3wz/LNHKpQ5nX8hjsDLRhsyeIi
# Jsms9yAWnvdYOdEMq1W61KE9JlBkB20XBee6JaXx4UBErc+YuoSb1SxVf7nkNtUj
# PfcxuFtrQdRMRi/fInV/AobE8Gw/8yBMQKKaHt5eia8ybT8Y/Ffa6HAJyz9gvEOc
# F1VWXG8OMeM7Vy7Bs6mSIkYeYtddU1ux1dQLbEGur18ut97wgGwDiGinCwKPyFO7
# ApcmVJOtlw9FVJxw/mL1TbyBns4zOgkaXFnnfzg4qbSvnrwyj1NiurMp4pmAWjR+
# Pb/SIduPnmFzbSN/G8reZCL4fvGlvPFk4Uab/JVCSmj59+/mB2Gn6G/UYOy8k60m
# KcmaAZsEVkhOFuoj4we8CYyaR9vd9PGZKSinaZIkvVjbH/3nlLb0a7SBIkiRzfPf
# S9T+JesylbHa1LtRV9U/7m0q7Ma2CQ/t392ioOssXW7oKLdOmMBl14suVFBmbzrt
# 5V5cQPnwtd3UOTpS9oCG+ZZheiIvPgkDmA8FzPsnfXW5qHELB43ET7HHFHeRPRYr
# MBKjkb8/IN7Po0d0hQoF4TeMM+zYAJzoKQnVKOLg8pZVPT8xggSRMIIEjQIBATBp
# MFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAqBgNV
# BAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgQ0EgUjM2AhA6UmoshM5V
# 5h1l/MwS2OmJMA0GCWCGSAFlAwQCAgUAoIIB+TAaBgkqhkiG9w0BCQMxDQYLKoZI
# hvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI1MDEzMTE2MzEzNlowPwYJKoZIhvcN
# AQkEMTIEMDmuOSeP0ILS3o6pMIcUoXWV5YzwaxSbCJ/yNATjOhC6PfQ3J/8y41VM
# bOKPORZ0BTCCAXoGCyqGSIb3DQEJEAIMMYIBaTCCAWUwggFhMBYEFPhgmBmm+4gs
# 9+hSl/KhGVIaFndfMIGHBBTGrlTkeIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQsw
# CQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVT
# ZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HI
# Plz0x+M/MIG8BBSFPWMtk4KCYXzQkDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBD
# aXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVT
# RVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7Pd
# NsvJdWgwDQYJKoZIhvcNAQEBBQAEggIABxkWvNJ6tTERj+fBUICg+LRm8Q+IBekU
# iqmRnXDfE0xQS29jmO5TPGZrDa4jp7ILVKsPFBp4QRh7d2w+86AL7hBa6316jX6i
# 92fHEJfxzGbvpYtzp/KTf68N5TgKuzw/qsSr9vYLSYmniCSMBiQdQUML+UgRAEMX
# taWmRI/GhUMi9O821W4KZIuZ3r5fZ3reIM/4Cn0wr9mVInM6yt7iYW5BZfL87g5x
# qqSojSskRoLtCxEHImkppqxyfslxkCuWHiD39d99Q8SzcArqw/7FEqlg4Jb//wsp
# RaZTifUvS048Lpq8b/Fywlq/bcKOCDP1NrNff3VAp+eOhFAwGoejPdBH8bxNHic1
# KiXsyXMoHFryxGFkGJNDtO/a+1kI2aRwP2F36e0wSgQDDmcknEOtvhOcir+g/TNg
# +C0gFMGSI+EOfPkNhsVuwDAw0RV08VAXGfmxB//miiCq3Jx8r6z1gl1FsVp0rHKF
# JezcEoCOSeaKrp+vXUCbyqC32agOAU82J5fXImTNiKXEddLo+YuIp8z4L4lStW6Z
# U/hV+n6foW2i1/BWvYyI5zFOmF74wCZ7b27y7NFLGDYLOwYRW8aQ4vm7T+JZ8QPO
# q+0WHp7vvf3vNSb7BXjNbyjc0Ol48aim9OpnyZSVX7AUC7oi9pFCBpz21uNcV3yw
# MeK58FtCxJI=
# SIG # End signature block
