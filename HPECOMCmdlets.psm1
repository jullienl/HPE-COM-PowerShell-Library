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
[Version]$ModuleVersion = '1.0.28'

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
# MIIqQAYJKoZIhvcNAQcCoIIqMTCCKi0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCi0TK3FQW06Le8
# cOMqdZiqxE1RK13032eOfYpomkp0zKCCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
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
# A+rbZZyGZkz3xbUYKTGCHRMwgh0PAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMgQ29k
# ZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUDBAIB
# BQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# qwfen7KvD4r38bOK+Z/Xa2RoqG9xJbeU2Nw/1ZKFwg0wDQYJKoZIhvcNAQEBBQAE
# ggIAGygFviDcVZ7EH0xO3aFIXGe2wta1VVneuPO1v/LIZoQyilG9qUC8dW2VFa9W
# MBBUcMubBNHIotrtBicoC+f8MmOSsjwGizdmbI7X2ZeKjM3eL15PN25X+hugBiN5
# /ISif8sQFkDxugPCDAwxSbP6PKKIv+pjjiMaR35qZAZoC053gAL5STdBOj69JwCp
# lxbhRWCXirUgl+/JDPGR1fcqR4sjdOgVO5RqsZBe70p3SPF2/2vSiWD48LoSaXb8
# UHhiO6pEIt5v/LwIf5ZRiixMuZ6DzLWa6e7aKbCuLlKztk1S9sIjDr/rMesbRhyB
# R2jtO7JtXRGLjzCVkoSXIz3vZ5Cfb1+9iOSlZl9eJXvBogTXuzsTRtJi4yoQjRch
# igcRydZDdsPZPSzbHt2N0H5hGCQmfBh9kT/DwuqlJ5zzf78FJzhgEozrTkZ5X8X6
# kDz8QmeK9xuathtseuIXYHCNa1+YdOq0nAkZmvoujWAaahyaxJbMAea08NgOxpPM
# wf+VCpXt05Wjd3GpqhvupfWZembF2FxJwebYIUJt/q4g0+lFH6owCPUKkoMdHnGw
# SdmCaZLAQtJ0vADRWl5zBAo84KzTHVghSOG8d8RZJEpkSL4SJ9xyeH+t3teouu3t
# S1Mbyhf3cx8XsRtbJSll+u3QwP4gqweuWUEucPOZ2efabXmhghn9MIIZ+QYKKwYB
# BAGCNwMDATGCGekwghnlBgkqhkiG9w0BBwKgghnWMIIZ0gIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjECAQEw
# QTANBglghkgBZQMEAgIFAAQw7UbCNacP7moYlHTJIb2FRlKj5Tmql5ZlIgZw0omU
# w5IH6FCgZNFV76cZRqn4htBrAhUA2hBHw+RIP/WRamB9lEP6EnlTpwUYDzIwMjYx
# MTIzMDgzODIzWqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDkdyZWF0ZXIg
# TG9uZG9uMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMTJ1NlY3Rp
# Z28gUHVibGljIFRpbWUgU3RhbXBpbmcgU2lnbmVyIFIzN6CCFBcwggbiMIIEyqAD
# AgECAhEA507yVbBQT/rbpt/3/IujFTANBgkqhkiG9w0BAQwFADBVMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdv
# IFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFI0MTAeFw0yNjAzMjUwMDAwMDBaFw0z
# NzA2MjQyMzU5NTlaMHIxCzAJBgNVBAYTAkdCMRcwFQYDVQQIEw5HcmVhdGVyIExv
# bmRvbjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTAwLgYDVQQDEydTZWN0aWdv
# IFB1YmxpYyBUaW1lIFN0YW1waW5nIFNpZ25lciBSMzcwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCy/8NtS9xQ2UUtBRF32bj7VK3n4m50Uqjk/zTciSzi
# YV40H1LKah0/oEklYG42E4VCP3DvsBUB6DmpCkDZ0jCnZBPIEevaH15ZJOQwFWP2
# ZXr5YjlJpb68Nlbs+ElNvKx32/1YHde3qqUSLybjulxPLz6T85+HOIqK7M1Bep8L
# spyhEP/q6nw5kGxTSrGvufmeH+JF8CnVBcVMFA40FlIYh0cDJVFhhfTfdWgLy/vW
# uLMQoKkf3s/FvByf16r0rtbyHm/iemwxSioJL9zyZDDKUNAbHXl0dhXo2VxUV2Nc
# PXWXuoKsjL+6cfk6Vm2DHnxAlFdFsaBDIF1JOkSnC6PeLlBznZn2buF3vIIYJcq6
# N/zeFRCk4/HXDz7zgRsRRMdUB+rhyk5FoZaBjw0nLq3GZ3fClLUx5es5pUAxzNOD
# MBn7JkFYip2BAGBPER5eV0ROhk6tGTG+fUiMiV+vgjg1YnP5FvnYWyEtWeQD/B2h
# p3vz0RvtdkM0p3igyadzrfpOBq5ppVk/YsuhTQkP99ivneHAGfi5e7lmxJ+meoBP
# rRLuzMmb81rzzbESjJHMsn5RVtc6Ucs7rcMqQC13PUIO7BbGBETV2ufCmV6lPTp3
# P7XJOvmnUCRTPbVvMTpxP/z+SOHg4/OCBhiqs4FA9+4oQvlkk9w32NGASli9GWrm
# 5wIDAQABo4IBjjCCAYowHwYDVR0jBBgwFoAUOnSlDGfGQlDC/bX8x7spNIL0erkw
# HQYDVR0OBBYEFGEQ6XoSr1HEhdTyz6R0D1DNIK/4MA4GA1UdDwEB/wQEAwIGwDAM
# BgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEoGA1UdIARDMEEw
# CAYGZ4EMAQQCMDUGDCsGAQQBsjEBAgEDCDAlMCMGCCsGAQUFBwIBFhdodHRwczov
# L3NlY3RpZ28uY29tL0NQUzBKBgNVHR8EQzBBMD+gPaA7hjlodHRwOi8vY3JsLnNl
# Y3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVI0MS5jcmwwegYI
# KwYBBQUHAQEEbjBsMEUGCCsGAQUFBzAChjlodHRwOi8vY3J0LnNlY3RpZ28uY29t
# L1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVI0MS5jcnQwIwYIKwYBBQUHMAGG
# F2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4ICAQAD6j2N
# 0azN+hl6k6bKB5/U6VuSOs93ZBb3Pczy9VtBIKu4947Z5GwL0aFngIxl+GSuLFrJ
# gPruBCRvKJEJsm7kv+LQ1COVCEG9tZ+IRtr4ocUoa53lgdFaENlS0N4wgkZkbQEP
# v+x+1lSjYh+T4JeL9mUznT7Erc6Sp5dWLka5sMP/m3GZi6oJPdPcsCKWagH7m2H2
# xDGIyHJC5PdH9phvi/KmhkktiSVTNNqVeV5bWdX2zhRE6UTfz0IcMoCL996lFIyd
# XxOCE4MNDHDM0as4lnTiT/KHMccO6l8c9TnUVgmpci9ar1IABZ2U1XUkYjGGSn9M
# C3EHDP9V39VuBVvZ33/BEV/EWSRrf07T7jFplKX+gQr/UOqPGMlE7ZJ72UaUkNJy
# 7bVl3bcLKzdpjIHzLkf/4MVa1V7w8wqCv5W4gOnRGTlud5UMARbRM8BPxR/CXYXo
# MmIOD8pmTk2axgRL4LG8XtuchISdCHRmtacAmLGq5XSYSVTHTXADlO48iDKh3HM2
# r98LSF6f0sG12d8V9Jn7C3wDUieOxuKj4MdWrW+hiJU2kF87v6eH00HgCFFc2V0+
# CvfOCMn7juzS41jLaINcBlKWQ/fKb/uDLfWOW73z1I2lFY7Xj8tQ1XYtK5eREjWI
# tM8jpl1cbQOc88btR+0XS2TmboE/141+va2PWzCCBqcwggSPoAMCAQICEQCQrAhy
# IP3Fp8RrXMcN9z0GMA0GCSqGSIb3DQEBDAUAMFcxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRp
# bWUgU3RhbXBpbmcgUm9vdCBSNDYwHhcNMjYwMzI1MDAwMDAwWhcNNDEwMzI0MjM1
# OTU5WjBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSww
# KgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFI0MTCCAiIw
# DQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK7kSqIBrYIcYvlmLVuaA8zw1RfB
# hkn4G1CoemzjcYtML6yNUvKmwGH7y6/5MuSC1UYP/+9KYDSqvMQt/1hEKHYxMAD9
# oZpBkoaDQFEKbOJHelsKe+BaO0ZcENTKfePcraVkA7wrGAW2XHA5gQCQv4IKori/
# 3PNOXxnDMOk8yIMgVrlMeTxqfWJ4XkjT1xc2s9DD7URHWWJOFobTPoWs6mrDFlaY
# 9FlAHDYTfbzvxQHVsvRmn3W+5ZmCwyk02I8KgGPT/UX4sTz41GiR+ppwUjQXa1+2
# tEHZbsdAKUtH3OPEVtZvlt7atx4h83IdRR8oYi8wjY3OjFKXFecWpQbzzsPxbUKP
# wMWiTrzwkrFa8dH/1pDKRJt371W62PfqKPayCr/XbnBOlRn8CALSmHnRtGzuAWtT
# JpcT3BKw6oy8IIL6wSbu938F6ZIbRNIc1dKbIJtr4ULN6R5ZfTdNEhwXctqp3RHD
# bg4fuOl6LjNoaFwjud92EEDhzxFJzE1jqN4csceZIwxOT1aqfsfh0uFQE/lgTBuB
# s3i6/WL2W1OceWLy3XEdXRK1f0EWCuea6dNfX2RRdjUfk5EltFnJkN2+bWhnK14O
# PRKcyjOv5hKZ0iV4NRNd1+hjtva1rPyzb5Bs7EvFxqEQhgZbOq7qH3nm0rBwA0dx
# niBOYCFPdu246JCxAgMBAAGjggFuMIIBajAfBgNVHSMEGDAWgBT2d2rdP/0BE/8W
# oWyCAi/QCj0UJTAdBgNVHQ4EFgQUOnSlDGfGQlDC/bX8x7spNIL0erkwDgYDVR0P
# AQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYBBQUH
# AwgwIwYDVR0gBBwwGjAIBgZngQwBBAIwDgYMKwYBBAGyMQECAQMIMEwGA1UdHwRF
# MEMwQaA/oD2GO2h0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1Rp
# bWVTdGFtcGluZ1Jvb3RSNDYuY3JsMHwGCCsGAQUFBwEBBHAwbjBHBggrBgEFBQcw
# AoY7aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0YW1w
# aW5nUm9vdFI0Ni5wN2MwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28u
# Y29tMA0GCSqGSIb3DQEBDAUAA4ICAQAy3lJHZvGeA2b43yhzoarvobHVzbfl+Rfu
# PDwej0wCQkYAN6scTt2GwFe22qbOCv/tllqFlLKQZE+E9jVyuPTbyQHwrM7R0oLa
# pAEDC1+CowsqSRf/ptira5Pfd4PoHICnb9coPQtyZmHSQp5y9IGvqWf1qNfq7V2f
# HZ8DvEQrLUzeoGF9BJRYu2OzacW3QQtUum3NOVf0gPRwv6I4991uhncJ6VP4lcpU
# pHZKB7R3hiIUC09mR9KjzPVnXHvL9n2bAwiUECfK5Zezhiw27F2tgi39DETfU8M4
# n0N6xLgFzsf05M5GURX8C9+IX9V6kpmmKtrUzMti4LD66gtmf+mSm934K81NL6YQ
# eMEk1rpYrWPypcW76Mir6wb1AgseLIHqn/GkeuQm7zOTDf3f5WoX14qVNjZWNHF3
# JxkutV6ZnhinfCLfdv5bnwKWUfceqOajCVntI6uCbHxjBg6SCsexc5AfIGno7gVF
# vwifT4XONPsSUaJ71XsJ+EvciVUVnjOO4qxm0fWJTd8a7jP8mc4ZPqwJvQFtOp7+
# 6G+kUJAF0fnE8YgD8uttBReNTa1YmAeFMiqc38e8fI4eLm0zjM/eeGCHasnoqqrb
# GwcF41iz9HXzFDwN4iD5z3QShp6HRiU3UpTwDJiiXcr0z6pjl7PyzJ3/tmWtGehV
# 7CAfc/WlyzCCBoIwggRqoAMCAQICEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcN
# AQEMBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQwEgYD
# VQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3b3Jr
# MS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9yaXR5
# MB4XDTIxMDMyMjAwMDAwMFoXDTM4MDExODIzNTk1OVowVzELMAkGA1UEBhMCR0Ix
# GDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJs
# aWMgVGltZSBTdGFtcGluZyBSb290IFI0NjCCAiIwDQYJKoZIhvcNAQEBBQADggIP
# ADCCAgoCggIBAIid2LlFZ50d3ei5JoGaVFTAfEkFm8xaFQ/ZlBBEtEFAgXcUmanU
# 5HYsyAhTXiDQkiUvpVdYqZ1uYoZEMgtHES1l1Cc6HaqZzEbOOp6YiTx63ywTon43
# 4aXVydmhx7Dx4IBrAou7hNGsKioIBPy5GMN7KmgYmuu4f92sKKjbxqohUSfjk1mJ
# lAjthgF7Hjx4vvyVDQGsd5KarLW5d73E3ThobSkob2SL48LpUR/O627pDchxll+b
# TSv1gASn/hp6IuHJorEu6EopoB1CNFp/+HpTXeNARXUmdRMKbnXWflq+/g36NJXB
# 35ZvxQw6zid61qmrlD/IbKJA6COw/8lFSPQwBP1ityZdwuCysCKZ9ZjczMqbUcLF
# yq6KdOpuzVDR3ZUwxDKL1wCAxgL2Mpz7eZbrb/JWXiOcNzDpQsmwGQ6Stw8tTCqP
# umhLRPb7YkzM8/6NnWH3T9ClmcGSF22LEyJYNWCHrQqYubNeKolzqUbCqhSqmr/U
# dUeb49zYHr7ALL8bAJyPDmubNqMtuaobKASBqP84uhqcRY/pjnYd+V5/dcu9ieER
# jiRKKsxCG1t6tG9oj7liwPddXEcYGOUiWLm742st50jGwTzxbMpepmOP1mLnJskv
# ZaN5e45NuzAHteORlsSuDt5t4BBRCJL+5EZnnw0ezntk9R8QJyAkL6/bAgMBAAGj
# ggEWMIIBEjAfBgNVHSMEGDAWgBRTeb9aqitKz1SA4dibwJ3ysgNmyzAdBgNVHQ4E
# FgQU9ndq3T/9ARP/FqFsggIv0Ao9FCUwDgYDVR0PAQH/BAQDAgGGMA8GA1UdEwEB
# /wQFMAMBAf8wEwYDVR0lBAwwCgYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRVHSAA
# MFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9VU0VS
# VHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDA1BggrBgEFBQcBAQQp
# MCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZI
# hvcNAQEMBQADggIBAA6+ZUHtaES45aHF1BGH5Lc7JYzrftrIF5Ht2PFDxKKFOct/
# awAEWgHQMVHol9ZLSyd/pYMbaC0IZ+XBW9xhdkkmUV/KbUOiL7g98M/yzRyqUOZ1
# /IY7Ay0YbMniIibJrPcgFp73WDnRDKtVutShPSZQZAdtFwXnuiWl8eFARK3PmLqE
# m9UsVX+55DbVIz33Mbhba0HUTEYv3yJ1fwKGxPBsP/MgTECimh7eXomvMm0/GPxX
# 2uhwCcs/YLxDnBdVVlxvDjHjO1cuwbOpkiJGHmLXXVNbsdXUC2xBrq9fLrfe8IBs
# A4hopwsCj8hTuwKXJlSTrZcPRVSccP5i9U28gZ7OMzoJGlxZ5384OKm0r568Mo9T
# YrqzKeKZgFo0fj2/0iHbj55hc20jfxvK3mQi+H7xpbzxZOFGm/yVQkpo+ffv5gdh
# p+hv1GDsvJOtJinJmgGbBFZIThbqI+MHvAmMmkfb3fTxmSkop2mSJL1Y2x/955S2
# 9Gu0gSJIkc3z30vU/iXrMpWx2tS7UVfVP+5tKuzGtgkP7d/doqDrLF1u6Ci3TpjA
# ZdeLLlRQZm867eVeXED58LXd1Dk6UvaAhvmWYXoiLz4JA5gPBcz7J311uahxCweN
# xE+xxxR3kT0WKzASo5G/PyDez6NHdIUKBeE3jDPs2ACc6CkJ1Sji4PKWVT0/MYIE
# kzCCBI8CAQEwajBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1p
# dGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFI0
# MQIRAOdO8lWwUE/626bf9/yLoxUwDQYJYIZIAWUDBAICBQCgggH6MBoGCSqGSIb3
# DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYxMTIzMDgzODIz
# WjA/BgkqhkiG9w0BCQQxMgQwI4n+TyeEfQHhcmrR4n9sWOOX5b1FuhFif2PNPVdj
# 9ozPyOKiHKs+VNExmbw1r0W3MIIBewYLKoZIhvcNAQkQAgwxggFqMIIBZjCCAWIw
# FgQU6XgYqSjaFQqf4b+czHqruaAO7qwwgYgEFGXDKGlvfU5QLP0Dx8IGlxjK+/dP
# MHAwW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQx
# LjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgUm9vdCBSNDYC
# EQCQrAhyIP3Fp8RrXMcN9z0GMIG8BBSFPWMtk4KCYXzQkDXEkd6SwULaxzCBozCB
# jqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNV
# BAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsx
# LjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkC
# EDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAEggIAV4exm9/uv661yYhJ
# 7CVGO3Ibhy+a2fiya5te0rHtdr7Ow5LdJfvbp6zQe1PYUCYc3Qsc4iUd6j/fECQT
# 32hGneZxI8t2rM2Q/IXlQn4BaBSOZlOR7X4LN5yhg4i3KBpwoQHLl8C0ZS6NvBLx
# kxVJemKHb5pyA4SoeRtgZ3J5G6LmeVcZi4q1pd0zQTfJJyqSZNU7yn6KgkgbgAZz
# PZlrZxtMYkYqPSiSkOrhtmZByGQQs+PX4tOGUCX7QZV7gpOoE337n5IbKLchRgyO
# Z0FikjOSzHOL2qpFz0UaX7y0qnNQkRykcRarJRJUSswPKAn9//LUUVHsQ0O6Pbuo
# ToA/Rjqp4E4Wg7HxlLx9iAG+gIqxhG13zv6Q6v5U23yQ+pNbDA/+sfUIO3gsb3Ut
# YB1uNvzOL7192a76d2ByX1JDQWbdfVbirfEXai/Dsz32QRr6uBN/YeXXrIbgdFF3
# kEV95/4ahwpIMDgmbQ8h2vtL0WcKdQTVJPMqlo/rpH7V6kSasOKFHUVAqeJ/rXSG
# +rXBTtitK4aP51XAhMv94bHSx52ONepl3xACYxMqeCy2iEo9896OkpThxvdsW+Gm
# Q3QhiOzbtdBGBud0GljQxi6fhkLd+KM+JNpNhFd8YvFwGkHoPLjxLyMdpx7OZajT
# KxS1Ns4YDEgpG7D56e5fbsbjjPQ=
# SIG # End signature block
