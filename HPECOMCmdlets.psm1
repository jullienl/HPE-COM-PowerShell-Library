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
[Version]$ModuleVersion = '1.0.18'

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
    Write-Warning "Failed to load supported languages from $languageUrl : $_"
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
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB3fbpuRDM+HlCZ
# eqXp/1Q6buUpKMtHi9t4aDSyrlTiyKCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQg9jBHvpUXCGs6xS7Cb1AH2jpw0jQnzxv3qhwXLn3ZFZswDQYJKoZIhvcNAQEB
# BQAEggIAggxqn+N5lCHaw3PSVb7pj+Uu6bF5dEnbE+OIclXtlJeMS9S300zMm/rE
# KI9/yz2CDZ9BwOt4kl/3YlPMSWUYd8y1ezFRbcep7rpxMJ/Jgw9bffznzk68KEqb
# OTu4AohsZS5kH4yFHiIT4eB9PdewvYFJMoKxqZQ70v7Cra5RzjRYXKKyStASfF5g
# 9SAqz09KuQvFil30iPTJ57JywbXLuljmVRvDU8SaE2c6y9zg6sJ6d/ElKCE1V0J6
# yI408WTI6zvoEZ7FkTFturRLCAY3oMtnYTNN+yPMQlCMWNOVEBJKv+bPNXwGI7yL
# ow4GhhchhuiKxWFMHcjwHGZHYylLtJeLmNV0PxogLSOrIDnjMfKLd6mgncVptNL3
# dfUU98t/Co2wqA8EboYxebi7szVyyXXEXqazNDXqeWLXfOpynSW0wpPHerROthEI
# pCEP/iMkbyMn3QFvGlwf97L0Clcbo90hUkW1Afe6h+pZ28JkJ2K9baSvJvRCn2Gq
# j59PTS1P/kpRSjgGiiGoJA5eFvtvoIP9oSkJT15kl/VPx5LV8JDhVq3DvkCGPzie
# jCJyiSPkvBg4M7tQOAwMgBo3uteLPJAgLTAQLCe2vQ4qDoP3UcbacvsR6YzJEblJ
# K/N8LSn+KgreLEHb82P18aNJhtV0tuRa4+Le7velSKMlPpGfUlChghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwBMOd2+rTMsgMmzDm11Zb8UYNR1K4Q5Yvxf53
# +kQw/xXzzRZzJNqWq89vM8Gwa2RxAhQLozTzbW3kXEMtZKuvyjSAaiVirhgPMjAy
# NTExMjUxNTMyNTFaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
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
# DxcNMjUxMTI1MTUzMjUxWjA/BgkqhkiG9w0BCQQxMgQwkydnGqqXOlE5edshVMr6
# 3Jw2xUFdkB0ZY5RD9kA9+5k6ctG54XytEwCP01xQOn7EMIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgAYfd0jYlUe6oNOmL+4NoA3M78tarWQasL6hU0asm9swx/ti2wgsDi0obF85sIY
# qwGRq8kKLc2Dh9UCmZ1cl9Hnc3izEEJM8f3+FpOivIJvT/ZMwdi4H4iTiYqVTJh2
# G6RkxFAj0BYZF7PxhooxjIHUhr7MCAJXxjsvpA2wUKWn+mT7/3SbK2visBKeEHKY
# AdEBpuv3m/IkagZCbZDbzB0lZVcdCLkdbt/ZtFAD/IGokBZxtxWa6gZPXnh8x+LU
# QVqF1gav9YJLBsVFt2Gz6JMGUndOPMK1L2qjE/lvfbaPYtJwcpdqTT8Z44HubO+p
# sFoT0nAUIjW/obBa3obrDrukOZrwZHUq0Ev5Hqofzh71kcdsB/bJZEBXNuysLb7g
# DV6n1NOAnApZmAnnST08o8FDPy7kWeGqE7dYp+ugvfxZgf28Y6lfbthZXv/z0OWr
# fQjSQKq9F8uk720qYc9UMp27KGAal9xq+1ADEneNfl3snmNt7PEf+uS1jSwQtDqJ
# uER1q8h9C7PUQw0909ImFLcGeqmnF7slPs3Xlk0bPeiSjowVYv3jXUyTBM3ii9q+
# N1XN6iSABS8vbpXN518tZMsEqGX+rq/SL6LfIz4IPyHMdvKrI5t7zRBu4i0/VoJh
# JFDwce2/Z79S9okByxJ4y48YmFyFuhrann4ijILi83z30g==
# SIG # End signature block
