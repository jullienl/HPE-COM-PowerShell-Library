##############################################################################
# HPE Compute Ops Management PowerShell Library
##############################################################################
<#
(C) Copyright 2013-2025 Hewlett Packard Enterprise Development LP

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
THE SOFTWARE.
#>

# Set PowerShell library version
[Version]$ModuleVersion = '1.0.27'

# Set the module version as a global variable
$Global:HPECOMCmdletsModuleVersion = $ModuleVersion

#Region ---------------------------- OBJECT FORMATTING DEFINITIONS -------------------------------------------------------------------------------------------------------------------------------------------

Get-ChildItem -Path $PSScriptRoot -Recurse -Include *.Format.PS1XML | ForEach-Object {
    try {
        Update-FormatData -AppendPath $_.FullName -ErrorAction Stop
        # Write-Verbose "Loaded format file: $($_.FullName)" -Verbose
    } catch {
        Write-Warning "Failed to load format file $($_.FullName): $_"
    }
}

#EndRegion

#Region ---------------------------- ARGUMENT COMPLETER -------------------------------------------------------------------------------------------------------------------------------------------

$httpMethods = 'GET', 'POST', 'PUT', 'DELETE', 'HEAD', 'OPTIONS', 'PATCH', 'TRACE', 'CONNECT'

Register-ArgumentCompleter -CommandName Invoke-HPEGLWebRequest, Invoke-HPECOMWebRequest -ParameterName Method -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $httpMethods | Where-Object { $_.StartsWith($wordToComplete, [StringComparison]::OrdinalIgnoreCase) } |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

Register-ArgumentCompleter -CommandName 'Set-HPEGLUserAccountDetails', 'Set-HPEGLUserPreference' -ParameterName Language -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $global:HPESupportedLanguages.Keys | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        $completionText = if ($_ -match "\s") { "'$_'" } else { $_ }
        [System.Management.Automation.CompletionResult]::new($completionText, $_, 'ParameterValue', $_)
    }
}

Register-ArgumentCompleter -CommandName 'Set-HPEGLUserAccountDetails' -ParameterName TimeZone -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $timeZoneIds = $Global:HPEGLSchemaMetadata.hpeTimezones
    $timeZoneIds | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        $timeZoneName = $_
        $completionText = if ($timeZoneName -match "\s") { "'$timeZoneName'" } else { $timeZoneName }
        [System.Management.Automation.CompletionResult]::new($completionText, $_, 'ParameterValue', $_)
    }
}

Register-ArgumentCompleter -CommandName 'Set-HPEGLUserAccountDetails', 'Set-HPEGLWorkspace', 'New-HPEGLWorkspace', 'New-HPEGLLocation', 'Set-HPEGLLocation' -ParameterName Country -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    $Countries = $Global:HPEGLSchemaMetadata.hpeCountryCodes.Name
    $Countries | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        $countryName = $_
        $completionText = if ($countryName -match "\s") { "'$countryName'" } else { $countryName }
        [System.Management.Automation.CompletionResult]::new($completionText, $_, 'ParameterValue', $_)
    }
}

#EndRegion

#Region ---------------------------- VARIABLES -------------------------------------------------------------------------------------------------------------------------------------------

# IMPORTANT: These two lookups (languages, countries) must stay synchronous and complete before Import-Module returns.
# New-HPEGLWorkspace runs before any session/workspace exists, so it has no other way to get this data — do not make
# these calls asynchronous/background (e.g. via Start-Job/Start-ThreadJob) or New-HPEGLWorkspace will break.
# On networks where a security/inspection appliance adds several seconds to every first connection to a host,
# these calls can take longer than usual — -TimeoutSec is set high enough to tolerate that.

# Load supported languages from HPE Auth service and store them in a global variable
$languageUrl = 'https://auth.hpe.com/messages/supportedLanguagesList.json'
try {
    $response = Invoke-RestMethod -Uri $languageUrl -Method Get -TimeoutSec 30
    $global:HPESupportedLanguages = @{}
    foreach ($langDetail in $response.supportedLanguagesListDetails) {
        $Global:HPESupportedLanguages[$langDetail.label] = $langDetail.value
    }
} catch {
    Write-Warning "Unable to retrieve supported languages from $languageUrl. Please check your internet connection or try again later."
    $global:HPESupportedLanguages = @{}
}

# Load country list from HPE GreenLake geo API and store in a global variable
# (used by 'Set-HPEGLUserAccountDetails', 'Set-HPEGLWorkspace', 'New-HPEGLLocation', 'Set-HPEGLLocation')
# and timezones (used by 'Set-HPEGLUserAccountDetails')
$countryUrl = 'https://aquila-user-api.common.cloud.hpe.com/geo/ui/v1/countries?status=AVAILABLE'
try {
    $response = Invoke-RestMethod -Uri $countryUrl -Method Get -TimeoutSec 30
    $hpeCountryCodes = $response.countries | ForEach-Object {
        [PSCustomObject]@{
            Name = $_.name
            Code = $_.code
        }
    } | Sort-Object Name
} catch {
    Write-Warning "Unable to retrieve country list from $countryUrl. Please check your internet connection or try again later."
    # Silently fall back to empty — the list will be populated after Connect-HPEGLWorkspace establishes an authenticated session
    $hpeCountryCodes = @()
}

# Define IANA time zones
$TimeZones = @(
    "Africa/Cairo",
    "Africa/Casablanca",
    "Africa/Johannesburg",
    "Africa/Nairobi",
    "America/Adak",
    "America/Anchorage",
    "America/Buenos_Aires",
    "America/Chicago",
    "America/Costa_Rica",
    "America/Denver",
    "America/Halifax",
    "America/La_Paz",
    "America/Lima",
    "America/Los_Angeles",
    "America/Mazatlan",
    "America/Mexico_City",
    "America/New_York",
    "America/Nuuk",
    "America/Panama",
    "America/Phoenix",
    "America/Puerto_Rico",
    "America/Santiago",
    "America/Sao_Paulo",
    "America/St_Johns",
    "Asia/Almaty",
    "Asia/Baku",
    "Asia/Colombo",
    "Asia/Dhaka",
    "Asia/Dubai",
    "Asia/Irkutsk",
    "Asia/Jakarta",
    "Asia/Jerusalem",
    "Asia/Kabul",
    "Asia/Karachi",
    "Asia/Kathmandu",
    "Asia/Kolkata",
    "Asia/Krasnoyarsk",
    "Asia/Rangoon",
    "Asia/Riyadh",
    "Asia/Seoul",
    "Asia/Shanghai",
    "Asia/Singapore",
    "Asia/Taipei",
    "Asia/Tokyo",
    "Asia/Vladivostok",
    "Asia/Yakutsk",
    "Asia/Yekaterinburg",
    "Atlantic/Azores",
    "Atlantic/Cape_Verde",
    "Atlantic/South_Georgia",
    "Australia/Adelaide",
    "Australia/Brisbane",
    "Australia/Darwin",
    "Australia/Hobart",
    "Australia/Perth",
    "Australia/Sydney",
    "Canada/Saskatchewan",
    "Etc/GMT",
    "Etc/GMT-1",
    "Etc/GMT-10",
    "Etc/GMT-11",
    "Etc/GMT-12",
    "Etc/GMT-2",
    "Etc/GMT-3",
    "Etc/GMT-4",
    "Etc/GMT-5",
    "Etc/GMT-6",
    "Etc/GMT-7",
    "Etc/GMT-8",
    "Etc/GMT-9",
    "Etc/GMT+1",
    "Etc/GMT+10",
    "Etc/GMT+11",
    "Etc/GMT+12",
    "Etc/GMT+2",
    "Etc/GMT+3",
    "Etc/GMT+4",
    "Etc/GMT+5",
    "Etc/GMT+6",
    "Etc/GMT+7",
    "Etc/GMT+8",
    "Etc/GMT+9",
    "Europe/Athens",
    "Europe/Belgrade",
    "Europe/Berlin",
    "Europe/Helsinki",
    "Europe/London",
    "Europe/Moscow",
    "Europe/Paris",
    "Europe/Warsaw",
    "Pacific/Auckland",
    "Pacific/Fiji",
    "Pacific/Guadalcanal",
    "Pacific/Guam",
    "Pacific/Honolulu",
    "Pacific/Marquesas",
    "Pacific/Samoa",
    "Pacific/Tongatapu"
) | Sort-Object

# Create the global metadata object
$Global:HPEGLSchemaMetadata = [PSCustomObject]@{
    hpeCountryCodes = $hpeCountryCodes
    hpeTimezones    = $TimeZones
}


#EndRegion

#Region ---------------------------- CLASS DEFINITIONS -------------------------------------------------------------------------------------------------------------------------------------------

function Test-TypeExists {
    param (
        [string]$TypeName
    )
    return [AppDomain]::CurrentDomain.GetAssemblies() |
        ForEach-Object { $_.GetType($TypeName, $false, $false) } |
        Where-Object { $_ -ne $null }
}

if (-not (Test-TypeExists -TypeName 'HtmlContentDetectedException')) {
    Add-Type @"
    using System;
    public class HtmlContentDetectedException : Exception
    {
        public HtmlContentDetectedException() : base("HTML content detected in response.") { }
        public HtmlContentDetectedException(string message) : base(message) { }
        public HtmlContentDetectedException(string message, Exception innerException) : base(message, innerException) { }
    }
"@
}

#EndRegion

#Region ---------------------------- SUBMODULE IMPORTS -------------------------------------------------------------------------------------------------------------------------------------------

# Dynamically import all submodules in the 'Modules' directory
$moduleRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$subModules = Get-ChildItem -Path (Join-Path $moduleRoot 'Modules') -Filter *.psm1 -File | 
    Sort-Object Name | 
    ForEach-Object { Join-Path 'Modules' $_.Name }

    
foreach ($subModule in $subModules) {
    $subModulePath = Join-Path $moduleRoot $subModule
    if (Test-Path -Path $subModulePath -PathType Leaf) {
        try {
            Import-Module $subModulePath -DisableNameChecking -Force -ErrorAction Stop
            # Write-Verbose "Imported submodule: $subModule" -Verbose
        } catch {
            Write-Warning "Failed to import submodule $subModule : $_"
        }
    } else {
        Write-Warning "Submodule not found: $subModulePath"
    }
}

#EndRegion

#Region ---------------------------- EXPORT MEMBERS -------------------------------------------------------------------------------------------------------------------------------------------

Export-ModuleMember -Function * -Alias *

#EndRegion

#Region ---------------------------- WELCOME BANNER -------------------------------------------------------------------------------------------------------------------------------------------

# Display a short, getting-started banner when the module is imported in an interactive console session.
# This points first-time users to the offline help topic and the GitHub documentation.
# The banner is shown in interactive hosts (the PowerShell console and the VS Code PowerShell terminal),
# and is suppressed automatically in CI/CD pipelines, scripted/non-interactive runs (pwsh -File / -Command /
# -EncodedCommand) and other non-interactive hosts. It can also be disabled explicitly by setting
# $env:HPECOMCMDLETS_NO_BANNER to a truthy value ('1', 'true', 'yes' or 'on') before importing the module.
$_InteractiveHosts = @('ConsoleHost', 'Visual Studio Code Host')
$_IsCIEnvironment  = [bool]($env:CI -or $env:TF_BUILD -or $env:GITHUB_ACTIONS -or $env:JENKINS_URL -or $env:GITLAB_CI)
# Interpret HPECOMCMDLETS_NO_BANNER as a boolean. Environment variables are strings, so a naive '-not $env:...' would
# treat the string '0' (and 'false') as truthy and suppress the banner. Only treat explicit truthy values as "hide".
$_BannerDisabled   = ($env:HPECOMCMDLETS_NO_BANNER -in @('1', 'true', 'yes', 'on'))
# Detect scripted/non-interactive invocation (e.g. pwsh -File script.ps1, pwsh -Command "...", pwsh -EncodedCommand ...).
# This heuristic only applies to the regular console host (ConsoleHost): the VS Code PowerShell Extension host
# ('Visual Studio Code Host') is started by PowerShell Editor Services with -Command but no -NoExit, yet it is always
# an interactive session, so it must never be treated as scripted.
# For ConsoleHost, interactive launchers (e.g. the VS Code integrated terminal) pass -Command together with -NoExit, so
# the session is only treated as scripted when a script/command argument is present WITHOUT -NoExit (and -NonInteractive always counts).
$_CmdLineArgs          = [Environment]::GetCommandLineArgs()
$_HasNoExit            = [bool]($_CmdLineArgs | Where-Object { $_ -match '^-(NoExit|noe)$' } | Select-Object -First 1)
$_HasNonInteractive    = [bool]($_CmdLineArgs | Where-Object { $_ -match '^-(NonInteractive|noni)$' } | Select-Object -First 1)
$_HasScriptArg         = [bool]($_CmdLineArgs | Where-Object { $_ -match '^-(File|f|Command|c|EncodedCommand|e|ec)$' } | Select-Object -First 1)
$_IsScriptedInvocation = ($Host.Name -eq 'ConsoleHost') -and ($_HasNonInteractive -or ($_HasScriptArg -and -not $_HasNoExit))

if (-not $_BannerDisabled -and $Host.Name -in $_InteractiveHosts -and -not $_IsCIEnvironment -and -not $_IsScriptedInvocation) {
    Write-Host ""
    Write-Host "HPE Compute Ops Management PowerShell Library v$ModuleVersion" -ForegroundColor Cyan
    Write-Host "  First step      : " -NoNewline; Write-Host "Connect-HPEGL" -ForegroundColor Yellow
    Write-Host "  Getting started : " -NoNewline; Write-Host "Get-Help about_HPECOMCmdlets" -ForegroundColor Yellow
    Write-Host "  Documentation   : https://github.com/jullienl/HPE-COM-PowerShell-Library"
    Write-Host "  (Hide this banner: set `$env:HPECOMCMDLETS_NO_BANNER = '1')" -ForegroundColor DarkGray
    Write-Host ""
}

#EndRegion

# SIG # Begin signature block
# MIIn2gYJKoZIhvcNAQcCoIInyzCCJ8cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBg/QRolchX9Iay
# PjIvoIO4BntX2PvT45V2woxI3yZrSaCCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
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
# ejYNDA4+6C8bbbeSfxEI/N88llyRpXPPETnVizNPzkUwDQYJKoZIhvcNAQEBBQAE
# ggIAUV4FFdBrICO51pVmbJmLqc12auxO7EInr2YvpKl5I5kLeF2IEPbsAPnSGtYz
# eTmXABV8eHK/z4VZg0bk0JvM/TRwQGIWQp8pHkZBW3H0WYfvi0Lqj/m1MxMjduKT
# p8gxDRhdy9hAK+f7EKT8yuTq8pPxO0jtrmjw8aoBaD1N8AzVGmSBLFEH7TwDpS0S
# sJMc34S04GUR8hEXIb3FaO19OWnWo+eF4/VvHCIiSjxi36cBYtNqZnK8JSLW2DNe
# 3l04FkQeAwQdA9iJjUNylcVELvrWancmVgvlKxVrdRxGCzd5sr56Cusc8jbP0PxK
# uRXpzbWvph15BYm9hxma83HDiRDi/TLfMbbyjaW9I3H9YC07Zj889SMDYKRDycl8
# 638Bqu9iz26PkIFXtCky8iX8NzqcYuTISJpz5qrT8ZYWxLHPoVUJ0Hj3ycEXsbX4
# mLki7nIfP4GiCBWtw1Sp91N8d45+hZQEs9CCy3FXrzKYQqZ5tzbUGNUmpmarj2Xv
# 3287YUT/H6tgxr+aAs8mPtDh93G12gMgsEv8TMiqW2yoodud5Qr1pGsslh6X8Bo9
# Fu7rcFk5adqoYiscNtoHuMNmQgr5IJpSXH/tlQ0Wk1jyyKuz3i06CSWmY1AlH1y6
# nbtJ5/pmHmMwZ1F9YxseUndpWWFN0Zw0yz1NVPqb2KFggo2hgheXMIIXkwYKKwYB
# BAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEwDQYJ
# YIZIAWUDBAICBQAEMFiJ2o3TPsbKvoFSXbJs7735T51XF1OIiaKUSiornDQD/QQg
# IHojIVnMvgcAj3jaYgIQbJAJS3jKtwKpP8ngZhguGhgPMjAyNjExMDQwODE3MDZa
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
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYxMTA0MDgx
# NzA2WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTpqKcjtIUE9eDhQ4tnPs6HzyxQ
# mzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCBxHdd7HC5xsmHXVY1pnAB3yX0SAzCa
# YI7cEFY0wVBQezA/BgkqhkiG9w0BCQQxMgQw9PJr5eRqFrRrc6Op6SuMO0+jCQP2
# SHO3LaRgtZdRHxfDKtiT2Ds1fQzb0G2okeLLMA0GCSqGSIb3DQEBAQUABIICAFrJ
# TL2bWTUtZhr0RkirdHXpsYpx4GSGHwi9l7EpADkkvzwgt/blxSau+FBSV1WaNZy8
# K6gQr5D3AyWJD/hqQzIeHcQq0EXvojgbGJ/LbqkfmZzd8C+uC8bJHZkHMRrHeci/
# TCqJlv6EZArvJdjgezwdN9bP680KwVV67GZ8Cj4HRBzUaBicuiqjDo2a2dPOF/JL
# ZbOhT2x3uHqrhBLW2fS23dPpWnjK+2VFE20aBDX3K30LbWW1AVOWby09lNkxFzJh
# mc1hGyLVBzuxofTqMmO5NyOoTqV6OymHAyBjtBcAoJ3V2XZ6PxCjw5FeqMcfjmrB
# uIcxkSeM/V3n+sidF+y6k3qlWjV/WZ87EuoN3h4VUE21TUSt0MMCVpoSAM3O8yJR
# KWY1VNhhl3xHW66o6tIgw6MGQXPlQ1Gc24VmVAn1kS5gXUqKBUHWOVijmAqkfPyS
# UCW83VhslM3p65iwF+xCQyQ74eLm1DINVjdDo5TMeNRQ/kDdTs/l+NXlrNsGtOCW
# XvluAGziaYxB4vfvVceGnLka4YyZYQcioqnGG5gGhJS06F76+r1fOlJA3g+nrVLv
# QW1CKO1JTf41Uib2gCKyV3BvvPb2Z3Of/b58Y+oXwnjGHf0bKPIc4bMv+Y7PKX8w
# VMq1RnlGb08bW/cpPBjj/0QT0D6oSdcUr2JwkyW2
# SIG # End signature block
