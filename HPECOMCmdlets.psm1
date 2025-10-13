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
[Version]$ModuleVersion = '1.0.17'

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
# MIIunwYJKoZIhvcNAQcCoIIukDCCLowCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCA9B6xpj2ud+Jc
# ymDB/W/DBCM3koOepiIkJReIuEWopKCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# nZ+oA+rbZZyGZkz3xbUYKTGCG/8wghv7AgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQgrCzI9Yge7RZAgdOXv7zfaRI8GyRhCeqOvg/dhPu94EwwDQYJKoZIhvcNAQEB
# BQAEggIA3gTbsRvKWhpuT6OUKcoRSb7FxZZiHJ+vHAbTTlu1Rw02N9J0ClweRB4V
# ul9GDDQA/tZB82DIyDtefjhrM8SIQalp3vp/KjDSHVr4rJqLPnJ8uzHFaHU3frc7
# B2YTaHIXJwMJqrp8Qk6yJWxKoE1LgdzZFdtFbADqz/xQgl9ql6OtP5FppH2gqIc1
# fB5mCbHlpyAbEtP6rn+LONJdzVFGQqEybxVQQkbwEKY8UCsb+72ibcQ+9yJX+Wcd
# tYkp9o36UZJZDpjgZ8LIWcmloQwOLArfTd3GLngp+k1I/VkzQwgEEqQmjBkOjGgp
# jcUtVtsHRGJglRn4NFzaaeYpOrSDiyWuCegkgqh+/Mb/DVeagyoxl+fddwraYFTD
# /q8lADB2mivhEdvq9Nh6pSHx02b+bTSnYbeUvTPMayKeODmNZITwFg3vsAfpj+is
# gmvivICIqE4bwGnMx6JmdO1oBqjIknT+c26JSsB7qxU5Ul01tewj8UAsXCmncrbL
# 5czpTt2vFp8p4M9WdpYHqjIhrdG79sR4hT51nA+MiBhmzlXXRg9mpLT5fhWp8L2o
# XXbRA+HEuFwKOL1E03WpNYcdwjfjnisUrbSde/+uOh5oemX6ULrC0Q3eQoWeZcFX
# G36v9zqynNxA/fJoUftYhIJTHKHShhiIdXlYtCLl91Tig3Xz2XahghjpMIIY5QYK
# KwYBBAGCNwMDATGCGNUwghjRBgkqhkiG9w0BBwKgghjCMIIYvgIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQw0/yvy5oxVMr7ulHtneofS3T26O/zRzyJ9sgP
# xvAZYqkOifkcIPi835ZWlgkOSBh5AhUA12p5mrg6gS/y59V24EhuKAPnHxMYDzIw
# MjUxMDEzMTIwMTI4WqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3Qg
# WW9ya3NoaXJlMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMTJ1Nl
# Y3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgU2lnbmVyIFIzNqCCEwQwggZiMIIE
# yqADAgECAhEApCk7bh7d16c0CIetek63JDANBgkqhkiG9w0BAQwFADBVMQswCQYD
# VQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0
# aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNjAeFw0yNTAzMjcwMDAwMDBa
# Fw0zNjAzMjEyMzU5NTlaMHIxCzAJBgNVBAYTAkdCMRcwFQYDVQQIEw5XZXN0IFlv
# cmtzaGlyZTEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTAwLgYDVQQDEydTZWN0
# aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFNpZ25lciBSMzYwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQDThJX0bqRTePI9EEt4Egc83JSBU2dhrJ+wY7Jg
# Reuff5KQNhMuzVytzD+iXazATVPMHZpH/kkiMo1/vlAGFrYN2P7g0Q8oPEcR3h0S
# ftFNYxxMh+bj3ZNbbYjwt8f4DsSHPT+xp9zoFuw0HOMdO3sWeA1+F8mhg6uS6BJp
# PwXQjNSHpVTCgd1gOmKWf12HSfSbnjl3kDm0kP3aIUAhsodBYZsJA1imWqkAVqwc
# Gfvs6pbfs/0GE4BJ2aOnciKNiIV1wDRZAh7rS/O+uTQcb6JVzBVmPP63k5xcZNzG
# o4DOTV+sM1nVrDycWEYS8bSS0lCSeclkTcPjQah9Xs7xbOBoCdmahSfg8Km8ffq8
# PhdoAXYKOI+wlaJj+PbEuwm6rHcm24jhqQfQyYbOUFTKWFe901VdyMC4gRwRAq04
# FH2VTjBdCkhKts5Py7H73obMGrxN1uGgVyZho4FkqXA8/uk6nkzPH9QyHIED3c9C
# GIJ098hU4Ig2xRjhTbengoncXUeo/cfpKXDeUcAKcuKUYRNdGDlf8WnwbyqUblj4
# zj1kQZSnZud5EtmjIdPLKce8UhKl5+EEJXQp1Fkc9y5Ivk4AZacGMCVG0e+wwGsj
# cAADRO7Wga89r/jJ56IDK773LdIsL3yANVvJKdeeS6OOEiH6hpq2yT+jJ/lHa9zE
# dqFqMwIDAQABo4IBjjCCAYowHwYDVR0jBBgwFoAUX1jtTDF6omFCjVKAurNhlxmi
# MpswHQYDVR0OBBYEFIhhjKEqN2SBKGChmzHQjP0sAs5PMA4GA1UdDwEB/wQEAwIG
# wDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEoGA1UdIARD
# MEEwNQYMKwYBBAGyMQECAQMIMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8vc2VjdGln
# by5jb20vQ1BTMAgGBmeBDAEEAjBKBgNVHR8EQzBBMD+gPaA7hjlodHRwOi8vY3Js
# LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVIzNi5jcmww
# egYIKwYBBQUHAQEEbjBsMEUGCCsGAQUFBzAChjlodHRwOi8vY3J0LnNlY3RpZ28u
# Y29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVIzNi5jcnQwIwYIKwYBBQUH
# MAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4IBgQAC
# gT6khnJRIfllqS49Uorh5ZvMSxNEk4SNsi7qvu+bNdcuknHgXIaZyqcVmhrV3PHc
# mtQKt0blv/8t8DE4bL0+H0m2tgKElpUeu6wOH02BjCIYM6HLInbNHLf6R2qHC1SU
# sJ02MWNqRNIT6GQL0Xm3LW7E6hDZmR8jlYzhZcDdkdw0cHhXjbOLsmTeS0SeRJ1W
# JXEzqt25dbSOaaK7vVmkEVkOHsp16ez49Bc+Ayq/Oh2BAkSTFog43ldEKgHEDBbC
# Iyba2E8O5lPNan+BQXOLuLMKYS3ikTcp/Qw63dxyDCfgqXYUhxBpXnmeSO/WA4Nw
# dwP35lWNhmjIpNVZvhWoxDL+PxDdpph3+M5DroWGTc1ZuDa1iXmOFAK4iwTnlWDg
# 3QNRsRa9cnG3FBBpVHnHOEQj4GMkrOHdNDTbonEeGvZ+4nSZXrwCW4Wv2qyGDBLl
# Kk3kUW1pIScDCpm/chL6aUbnSsrtbepdtbCLiGanKVR/KC1gsR0tC6Q0RfWOI4ow
# ggYUMIID/KADAgECAhB6I67aU2mWD5HIPlz0x+M/MA0GCSqGSIb3DQEBDAUAMFcx
# CzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMT
# JVNlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgUm9vdCBSNDYwHhcNMjEwMzIy
# MDAwMDAwWhcNMzYwMzIxMjM1OTU5WjBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIENBIFIzNjCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAM2Y
# 2ENBq26CK+z2M34mNOSJjNPvIhKAVD7vJq+MDoGD46IiM+b83+3ecLvBhStSVjeY
# XIjfa3ajoW3cS3ElcJzkyZlBnwDEJuHlzpbN4kMH2qRBVrjrGJgSlzzUqcGQBaCx
# pectRGhhnOSwcjPMI3G0hedv2eNmGiUbD12OeORN0ADzdpsQ4dDi6M4YhoGE9cbY
# 11XxM2AVZn0GiOUC9+XE0wI7CQKfOUfigLDn7i/WeyxZ43XLj5GVo7LDBExSLnh+
# va8WxTlA+uBvq1KO8RSHUQLgzb1gbL9Ihgzxmkdp2ZWNuLc+XyEmJNbD2OIIq/fW
# lwBp6KNL19zpHsODLIsgZ+WZ1AzCs1HEK6VWrxmnKyJJg2Lv23DlEdZlQSGdF+z+
# Gyn9/CRezKe7WNyxRf4e4bwUtrYE2F5Q+05yDD68clwnweckKtxRaF0VzN/w76kO
# LIaFVhf5sMM/caEZLtOYqYadtn034ykSFaZuIBU9uCSrKRKTPJhWvXk4CllgrwID
# AQABo4IBXDCCAVgwHwYDVR0jBBgwFoAU9ndq3T/9ARP/FqFsggIv0Ao9FCUwHQYD
# VR0OBBYEFF9Y7UwxeqJhQo1SgLqzYZcZojKbMA4GA1UdDwEB/wQEAwIBhjASBgNV
# HRMBAf8ECDAGAQH/AgEAMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBEGA1UdIAQKMAgw
# BgYEVR0gADBMBgNVHR8ERTBDMEGgP6A9hjtodHRwOi8vY3JsLnNlY3RpZ28uY29t
# L1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdSb290UjQ2LmNybDB8BggrBgEFBQcB
# AQRwMG4wRwYIKwYBBQUHMAKGO2h0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGln
# b1B1YmxpY1RpbWVTdGFtcGluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRw
# Oi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEAEtd7IK0ONVgM
# noEdJVj9TC1ndK/HYiYh9lVUacahRoZ2W2hfiEOyQExnHk1jkvpIJzAMxmEc6ZvI
# yHI5UkPCbXKspioYMdbOnBWQUn733qMooBfIghpR/klUqNxx6/fDXqY0hSU1OSkk
# Sivt51UlmJElUICZYBodzD3M/SFjeCP59anwxs6hwj1mfvzG+b1coYGnqsSz2wSK
# r+nDO+Db8qNcTbJZRAiSazr7KyUJGo1c+MScGfG5QHV+bps8BX5Oyv9Ct36Y4Il6
# ajTqV2ifikkVtB3RNBUgwu/mSiSUice/Jp/q8BMk/gN8+0rNIE+QqU63JoVMCMPY
# 2752LmESsRVVoypJVt8/N3qQ1c6FibbcRabo3azZkcIdWGVSAdoLgAIxEKBeNh9A
# QO1gQrnh1TA8ldXuJzPSuALOz1Ujb0PCyNVkWk7hkhVHfcvBfI8NtgWQupiaAeNH
# e0pWSGH2opXZYKYG4Lbukg7HpNi/KqJhue2Keak6qH9A8CeEOB7Eob0Zf+fU+CCQ
# aL0cJqlmnx9HCDxF+3BLbUufrV64EbTI40zqegPZdA+sXCmbcZy6okx/SjwsusWR
# ItFA3DE8MORZeFb6BmzBtqKJ7l939bbKBy2jvxcJI98Va95Q5JnlKor3m0E7xpMe
# YRriWklUPsetMSf2NvUQa/E5vVyefQIwggaCMIIEaqADAgECAhA2wrC9fBs656Oz
# 3TbLyXVoMA0GCSqGSIb3DQEBDAUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# TmV3IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBV
# U0VSVFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZp
# Y2F0aW9uIEF1dGhvcml0eTAeFw0yMTAzMjIwMDAwMDBaFw0zODAxMTgyMzU5NTla
# MFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNV
# BAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgUm9vdCBSNDYwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCIndi5RWedHd3ouSaBmlRUwHxJBZvM
# WhUP2ZQQRLRBQIF3FJmp1OR2LMgIU14g0JIlL6VXWKmdbmKGRDILRxEtZdQnOh2q
# mcxGzjqemIk8et8sE6J+N+Gl1cnZocew8eCAawKLu4TRrCoqCAT8uRjDeypoGJrr
# uH/drCio28aqIVEn45NZiZQI7YYBex48eL78lQ0BrHeSmqy1uXe9xN04aG0pKG9k
# i+PC6VEfzutu6Q3IcZZfm00r9YAEp/4aeiLhyaKxLuhKKaAdQjRaf/h6U13jQEV1
# JnUTCm511n5avv4N+jSVwd+Wb8UMOs4netapq5Q/yGyiQOgjsP/JRUj0MAT9Yrcm
# XcLgsrAimfWY3MzKm1HCxcquinTqbs1Q0d2VMMQyi9cAgMYC9jKc+3mW62/yVl4j
# nDcw6ULJsBkOkrcPLUwqj7poS0T2+2JMzPP+jZ1h90/QpZnBkhdtixMiWDVgh60K
# mLmzXiqJc6lGwqoUqpq/1HVHm+Pc2B6+wCy/GwCcjw5rmzajLbmqGygEgaj/OLoa
# nEWP6Y52Hflef3XLvYnhEY4kSirMQhtberRvaI+5YsD3XVxHGBjlIli5u+NrLedI
# xsE88WzKXqZjj9Zi5ybJL2WjeXuOTbswB7XjkZbErg7ebeAQUQiS/uRGZ58NHs57
# ZPUfECcgJC+v2wIDAQABo4IBFjCCARIwHwYDVR0jBBgwFoAUU3m/WqorSs9UgOHY
# m8Cd8rIDZsswHQYDVR0OBBYEFPZ3at0//QET/xahbIICL9AKPRQlMA4GA1UdDwEB
# /wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMIMBEG
# A1UdIAQKMAgwBgYEVR0gADBQBgNVHR8ESTBHMEWgQ6BBhj9odHRwOi8vY3JsLnVz
# ZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlmaWNhdGlvbkF1dGhvcml0eS5j
# cmwwNQYIKwYBBQUHAQEEKTAnMCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2Vy
# dHJ1c3QuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQAOvmVB7WhEuOWhxdQRh+S3OyWM
# 637ayBeR7djxQ8SihTnLf2sABFoB0DFR6JfWS0snf6WDG2gtCGflwVvcYXZJJlFf
# ym1Doi+4PfDP8s0cqlDmdfyGOwMtGGzJ4iImyaz3IBae91g50QyrVbrUoT0mUGQH
# bRcF57olpfHhQEStz5i6hJvVLFV/ueQ21SM99zG4W2tB1ExGL98idX8ChsTwbD/z
# IExAopoe3l6JrzJtPxj8V9rocAnLP2C8Q5wXVVZcbw4x4ztXLsGzqZIiRh5i111T
# W7HV1AtsQa6vXy633vCAbAOIaKcLAo/IU7sClyZUk62XD0VUnHD+YvVNvIGezjM6
# CRpcWed/ODiptK+evDKPU2K6synimYBaNH49v9Ih24+eYXNtI38byt5kIvh+8aW8
# 8WThRpv8lUJKaPn37+YHYafob9Rg7LyTrSYpyZoBmwRWSE4W6iPjB7wJjJpH2930
# 8ZkpKKdpkiS9WNsf/eeUtvRrtIEiSJHN899L1P4l6zKVsdrUu1FX1T/ubSrsxrYJ
# D+3f3aKg6yxdbugot06YwGXXiy5UUGZvOu3lXlxA+fC13dQ5OlL2gIb5lmF6Ii8+
# CQOYDwXM+yd9dbmocQsHjcRPsccUd5E9FiswEqORvz8g3s+jR3SFCgXhN4wz7NgA
# nOgpCdUo4uDyllU9PzGCBJIwggSOAgEBMGowVTELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJsaWMgVGlt
# ZSBTdGFtcGluZyBDQSBSMzYCEQCkKTtuHt3XpzQIh616TrckMA0GCWCGSAFlAwQC
# AgUAoIIB+TAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkF
# MQ8XDTI1MTAxMzEyMDEyOFowPwYJKoZIhvcNAQkEMTIEMFmDi9/+rsgsAaFxOnMR
# 1iGiyppRpiPOrupRy4NjVr1K7yRV+G+HPOOXpsKHdfIg3jCCAXoGCyqGSIb3DQEJ
# EAIMMYIBaTCCAWUwggFhMBYEFDjJFIEQRLTcZj6T1HRLgUGGqbWxMIGHBBTGrlTk
# eIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HIPlz0x+M/MIG8BBSFPWMtk4KCYXzQ
# kDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5l
# dyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNF
# UlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAE
# ggIAcEPzyVfQ4ta2IN9R3O5xa0A8/V8bxnxqPWGinhMlq95cKX4cX1L6XSIyxeGh
# VHWFBBmNwx+lrTVUhQ+L2FkAki8FU5vwmx86ZHTOkmByfvNJTuBdMQvFC54IqNGt
# ho6P1QQzYjOUoHabnogr/iY+O1USELqQ6RoKr1qM3Q6IV+3HVF0J8m//QLnGzy6q
# wimxxdpGrCe7oX8nsU4Nawu3IY/KkbURgSYLBapoyb+HVlGNIRSaxKujTHu3cLHw
# KlVpemTICDuVFJYNlN0s3hbPKCI7IrfPYn/FNEmHyvN5mPqkOS0TzFEBKgMIh11E
# qbAWnT164lLFAGxz5WgpkEHJHmszsj1DMVZqq4+x5bHZtFc6nYA5RvIByA8Yx5pC
# w/K471bgw9g08cdUZQS8zMlgA87FzxaCKTDSIcnCpGqmq/nD4MbZR6i5D3ljPyyS
# DmpgcoL8sVk/YNKdwRZcezXYizrnQO72kcQc6e9+wKMWlmkYqeLVJXypqlP4pKZi
# vs1zf0IQBmOKZgiVuWrx5ytWoAGcMyU2BTO003NlHmgxbKAMx1zTyCYBZDPgZowu
# QQGZWt1OFnRHWBDl+QE+xwOr8ZmdipDtpf8cNs18Nf0RUjethC6EZYsewBciIr5c
# fxIxV0RMbql10L2VhK+w7HMNJPKW6ziaVIrb0dI/6lO7wEI=
# SIG # End signature block
