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
[Version]$ModuleVersion = '1.0.21'

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

# Load supported languages from HPE Auth service and store them in a global variable
$languageUrl = 'https://auth.hpe.com/messages/supportedLanguagesList.json'
try {
    $response = Invoke-RestMethod -Uri $languageUrl -Method Get -TimeoutSec 10
    $global:HPESupportedLanguages = @{}
    foreach ($langDetail in $response.supportedLanguagesListDetails) {
        $Global:HPESupportedLanguages[$langDetail.label] = $langDetail.value
    }
} catch {
    Write-Warning "Unable to retrieve supported languages from $languageUrl. Please check your internet connection or try again later."
    $global:HPESupportedLanguages = @{}
}

# Set countries (used by 'Set-HPEGLUserAccountDetails', 'Set-HPEGLWorkspace', 'New-HPEGLLocation', 'Set-HPEGLLocation') and timezones (used by 'Set-HPEGLUserAccountDetails') and store them in a global variable
# Define the country code map (country name to ISO 3166-1 alpha-2 code)
$CountryCodeMap = @{
    "Afghanistan" = "AF"
    "Aland Islands" = "AX"
    "Albania" = "AL"
    "Algeria" = "DZ"
    "American Samoa" = "AS"
    "Andorra" = "AD"
    "Angola" = "AO"
    "Anguilla" = "AI"
    "Antarctica" = "AQ"
    "Antigua and Barbuda" = "AG"
    "Argentina" = "AR"
    "Armenia" = "AM"
    "Aruba" = "AW"
    "Australia" = "AU"
    "Austria" = "AT"
    "Azerbaijan" = "AZ"
    "Bahamas" = "BS"
    "Bahrain" = "BH"
    "Bangladesh" = "BD"
    "Barbados" = "BB"
    "Belarus" = "BY"
    "Belgium" = "BE"
    "Belize" = "BZ"
    "Benin" = "BJ"
    "Bermuda" = "BM"
    "Bhutan" = "BT"
    "Bolivia" = "BO"
    "Bonaire, Sint Eustatius and Saba" = "BQ"
    "Bosnia and Herzegovina" = "BA"
    "Botswana" = "BW"
    "Bouvet Island" = "BV"
    "Brazil" = "BR"
    "British Indian Ocean Territory" = "IO"
    "British Virgin Islands" = "VG"
    "Brunei" = "BN"
    "Bulgaria" = "BG"
    "Burkina Faso" = "BF"
    "Burundi" = "BI"
    "Cambodia" = "KH"
    "Cameroon" = "CM"
    "Canada" = "CA"
    "Cape Verde" = "CV"
    "Cayman Islands" = "KY"
    "Central African Republic" = "CF"
    "Chad" = "TD"
    "Chile" = "CL"
    "China" = "CN"
    "Christmas Island" = "CX"
    "Cocos Islands" = "CC"
    "Colombia" = "CO"
    "Comoros" = "KM"
    "Cook Islands" = "CK"
    "Costa Rica" = "CR"
    "Croatia" = "HR"
    "Cuba" = "CU"
    "Curacao" = "CW"
    "Cyprus" = "CY"
    "Czech Republic" = "CZ"
    "Democratic Republic of the Congo" = "CD"
    "Denmark" = "DK"
    "Djibouti" = "DJ"
    "Dominica" = "DM"
    "Dominican Republic" = "DO"
    "East Timor" = "TL"
    "Ecuador" = "EC"
    "Egypt" = "EG"
    "El Salvador" = "SV"
    "Equatorial Guinea" = "GQ"
    "Eritrea" = "ER"
    "Estonia" = "EE"
    "Ethiopia" = "ET"
    "Falkland Islands" = "FK"
    "Faroe Islands" = "FO"
    "Fiji" = "FJ"
    "Finland" = "FI"
    "France" = "FR"
    "French Polynesia" = "PF"
    "Gabon" = "GA"
    "Gambia" = "GM"
    "Georgia" = "GE"
    "Germany" = "DE"
    "Ghana" = "GH"
    "Gibraltar" = "GI"
    "Greece" = "GR"
    "Greenland" = "GL"
    "Grenada" = "GD"
    "Guadeloupe" = "GP"
    "Guam" = "GU"
    "Guatemala" = "GT"
    "Gu Bits" = "GG"
    "Guinea" = "GN"
    "Guinea-Bissau" = "GW"
    "Guyana" = "GY"
    "Haiti" = "HT"
    "Honduras" = "HN"
    "Hong Kong" = "HK"
    "Hungary" = "HU"
    "Iceland" = "IS"
    "India" = "IN"
    "Indonesia" = "ID"
    "Iran" = "IR"
    "Iraq" = "IQ"
    "Ireland" = "IE"
    "Isle of Man" = "IM"
    "Israel" = "IL"
    "Italy" = "IT"
    "Ivory Coast" = "CI"
    "Jamaica" = "JM"
    "Japan" = "JP"
    "Jersey" = "JE"
    "Jordan" = "JO"
    "Kazakhstan" = "KZ"
    "Kenya" = "KE"
    "Kiribati" = "KI"
    "Kosovo" = "XK"
    "Kuwait" = "KW"
    "Kyrgyzstan" = "KG"
    "Laos" = "LA"
    "Latvia" = "LV"
    "Lebanon" = "LB"
    "Lesotho" = "LS"
    "Liberia" = "LR"
    "Libya" = "LY"
    "Liechtenstein" = "LI"
    "Lithuania" = "LT"
    "Luxembourg" = "LU"
    "Macau" = "MO"
    "Macedonia" = "MK"
    "Madagascar" = "MG"
    "Malawi" = "MW"
    "Malaysia" = "MY"
    "Maldives" = "MV"
    "Mali" = "ML"
    "Malta" = "MT"
    "Marshall Islands" = "MH"
    "Martinique" = "MQ"
    "Mauritania" = "MR"
    "Mauritius" = "MU"
    "Mayotte" = "YT"
    "Mexico" = "MX"
    "Micronesia" = "FM"
    "Moldova" = "MD"
    "Monaco" = "MC"
    "Mongolia" = "MN"
    "Montenegro" = "ME"
    "Montserrat" = "MS"
    "Morocco" = "MA"
    "Mozambique" = "MZ"
    "Myanmar" = "MM"
    "Namibia" = "NA"
    "Nauru" = "NR"
    "Nepal" = "NP"
    "Netherlands" = "NL"
    "Netherlands Antilles" = "AN"
    "New Caledonia" = "NC"
    "New Zealand" = "NZ"
    "Nicaragua" = "NI"
    "Niger" = "NE"
    "Nigeria" = "NG"
    "Niue" = "NU"
    "North Korea" = "KP"
    "Northern Mariana Islands" = "MP"
    "Norway" = "NO"
    "Oman" = "OM"
    "Pakistan" = "PK"
    "Palau" = "PW"
    "Palestine" = "PS"
    "Panama" = "PA"
    "Papua New Guinea" = "PG"
    "Paraguay" = "PY"
    "Peru" = "PE"
    "Philippines" = "PH"
    "Pitcairn" = "PN"
    "Poland" = "PL"
    "Portugal" = "PT"
    "Puerto Rico" = "PR"
    "Qatar" = "QA"
    "Republic of the Congo" = "CG"
    "Reunion" = "RE"
    "Romania" = "RO"
    "Russia" = "RU"
    "Rwanda" = "RW"
    "Saint Barthelemy" = "BL"
    "Saint Helena" = "SH"
    "Saint Kitts and Nevis" = "KN"
    "Saint Lucia" = "LC"
    "Saint Martin" = "MF"
    "Saint Pierre and Miquelon" = "PM"
    "Saint Vincent and the Grenadine" = "VC"
    "Samoa" = "WS"
    "San Marino" = "SM"
    "Sao Tome and Principe" = "ST"
    "Saudi Arabia" = "SA"
    "Senegal" = "SN"
    "Serbia" = "RS"
    "Seychelles" = "SC"
    "Sierra Leone" = "SL"
    "Singapore" = "SG"
    "Sint Maarten" = "SX"
    "Slovakia" = "SK"
    "Slovenia" = "SI"
    "Solomon Islands" = "SB"
    "Somalia" = "SO"
    "South Africa" = "ZA"
    "South Georgia and the South Sandwich Islands" = "GS"
    "South Korea" = "KR"
    "South Sudan" = "SS"
    "Spain" = "ES"
    "Sri Lanka" = "LK"
    "Sudan" = "SD"
    "Suriname" = "SR"
    "Svalbard and Jan Mayen" = "SJ"
    "Swaziland" = "SZ"
    "Sweden" = "SE"
    "Switzerland" = "CH"
    "Syria" = "SY"
    "Taiwan" = "TW"
    "Tajikistan" = "TJ"
    "Tanzania" = "TZ"
    "Thailand" = "TH"
    "The French Republic" = "FR"
    "The Territory of Norfolk Island" = "NF"
    "Togo" = "TG"
    "Tokelau" = "TK"
    "Tonga" = "TO"
    "Trinidad and Tobago" = "TT"
    "Tunisia" = "TN"
    "Turkey" = "TR"
    "Turkmenistan" = "TM"
    "Turks and Caicos Islands" = "TC"
    "Tuvalu" = "TV"
    "U.S. Virgin Islands" = "VI"
    "Uganda" = "UG"
    "Ukraine" = "UA"
    "United Arab Emirates" = "AE"
    "United Kingdom" = "GB"
    "United States" = "US"
    "United States Minor Outlying Islands" = "UM"
    "Uruguay" = "UY"
    "Uzbekistan" = "UZ"
    "Vanuatu" = "VU"
    "Vatican" = "VA"
    "Venezuela" = "VE"
    "Vietnam" = "VN"
    "Wallis and Futuna" = "WF"
    "Western Sahara" = "EH"
    "Yemen" = "YE"
    "Zambia" = "ZM"
    "Zimbabwe" = "ZW"
}

# Create hpeCountryCodes from CountryCodeMap
$hpeCountryCodes = $CountryCodeMap.GetEnumerator() | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Key
        Code = $_.Value
    }
} | Sort-Object Name

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

# SIG # Begin signature block
# MIItTgYJKoZIhvcNAQcCoIItPzCCLTsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAxlUNVQ1vZiiVr
# miiyl5z9fUbeL4co+8BW2y6g0n66yqCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgVzf9L79Nj5u1Q0ApEfYdiUAQNZlU0f/5/dJPw4d7rIEwDQYJKoZIhvcNAQEB
# BQAEggIAFfanl98GFrg76IBvwx6tNRs/i9nXzjn2nYxz8N7t2JDsm+ip88huFKm0
# UH7aJ6bQxc7nMyAwl/naJpwgmwzPTqTMM2NWuWOjsDenCrkIXgOjYi0QywJLZtFQ
# JW8b8EnhbciZClvpLfMSp0KaXBIA9tmAcAVXMXCB5fHKfMyn++SAtwMQeIeo30oX
# NO8fzN0lWGz43NfUgUxRtdea/H2MjTWFyPuWVIiYW96FWozB8rfsMeW1DJbWKnD9
# t26I2jBSePA/M5Am6EewjZAK5PjfJIhYOfp6EENMsRk5OqSFjfDADbj2ROGUf/wz
# hZxA/9lvwLQbvphuTE8qrTPUnCnG3/sCVLF4MbcrWcoPDSN3IOEqPW6fz4sKV/r/
# fk16jP1uxb+iQPPbLBzTRsiUeooRrcdi6rqj5iAECh2nJ8s9grJUGeRqVc9yQE+J
# PGOlcoF9mXAsa01p40dV/MlLYlxopfY+hMk7uD/glE3cELM5jwQ67mwau7tVZTA7
# kawB7GyuSQfhzAAe+xHcRXTiysJ3HeDumYyMMjmffpEglXXNccUrvqOLgx8DxBUo
# lfAg/0q285tlWcovvEQ1QPlBng+3Xf9hP3VgsqxJYgWXeJo49BRTnsMcskvGQNs1
# f5+Yt3EFWoqu7cuGS0oseUjc9rfaMCPUK8HCAaC0CQJRLUoE2z2hgheYMIIXlAYK
# KwYBBAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMPCEGL5lWrvbxDTOx+1KdmCteZ2Qq/6fpXFiL2AzsdsX
# UQwMqE/UNTV5QtlYVW7AwQIRAO8/ov4NXBQbR5v9EEBP7sUYDzIwMjYwMjAyMDkz
# ODEzWqCCEzowggbtMIIE1aADAgECAhAMIENJ+dD3WfuYLeQIG4h7MA0GCSqGSIb3
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
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDIw
# MjA5MzgxM1owKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQUcrz9oBB/STSwBxxhD+bX
# llAAmHcwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgMvPjsb2i17JtTx0bjN29j4uE
# dqF4ntYSzTyqep7/NcIwPwYJKoZIhvcNAQkEMTIEMGRKUVbGx+mX43PXM4Wc64dM
# 23dDb9dpWlxhh3NNshFP+stzNeXGcokILJ6q5r0ZqDANBgkqhkiG9w0BAQEFAASC
# AgDBYvKE3CUOLcX8XEqAf4WN9PDNAd0sVQVNXfaNVdU3ODLYDIVBo61HVwB59wTh
# Gnjoh7mwuRTO+aAN5CnV7gh8Q48TR5mY5WiA/TU29LbCaNMc46YGdMHLeIqR7xfm
# FSC1a+I0C/ahnrpTmXg3VfdvgadIDgbokeovbibKhwa2eJp6kSH8NOHkZbTY/Rh9
# VvK7MRGTK+L5MxNqqWr1qzyioZWtSD5UVBEI/c4NZ0ePKW9ROtfk4wCvCHzAj4OS
# YO8i6VQZBQlha1Y0TAu7CATzNYZbiTCqJVpY5Plgi9T8X8ItpU2pCEBBdRe51Ktk
# kKs29+lzW024oK4FZ2OmK0r2pMXxKTvLtjKI++jSQXrMBkurxs05fflNdAhKGlAP
# /V6sCgiY+sDYAio+HC8jI8P4hftTunLQGVwmllfomflTUjNu6xVNsx+SZej0FGtt
# l3KKyBSXa49VDZFgLyLPviRPTcOte8mlpuZHJCdl7a6Ikb9vVcslMAFAqCwFfZos
# QF0JtsR6ls5fKfRASPX3VSNsAn2oPICQb4GBU3J+ODkVHO0vaUqh2WLOYPF5yTc2
# CyIopIJzxm6x0AsviRJptb87QrdW3HZlgUfUPhqtCP2ecdZwj+cPn+8G4np0TjC1
# hriFoMlJ7MHy/2VcycrzB0i6Pi6tJxcAOAEhu7mpqhQdRA==
# SIG # End signature block
