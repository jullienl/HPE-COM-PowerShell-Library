#------------------- HPE GreenLake SAML Single Sign-On (SSO) Authentication Flows -----------------------------------------------------------------------------------
#
# This module contains the SAML Single Sign-On (SSO) Identity-Provider authentication flows used by Connect-HPEGL:
#
#   - Invoke-EntraIDSSOAuthentication  : Microsoft Entra ID (Azure AD) SAML SSO (push / TOTP / password)
#   - Invoke-OktaSSOAuthentication     : Okta SAML SSO (Okta Verify push / TOTP / password)
#   - Invoke-PingIDSSOAuthentication   : PingOne / PingID SAML SSO (push / OTP / password)
#
# These functions were extracted from Connect-HPEGL (Utilities.psm1) to keep that file maintainable.
# They are self-contained: every input is passed as an explicit parameter (no reliance on the caller's
# local variables). The Update-ProgressBar helper below mirrors the one in Connect-HPEGL so the SSO
# flows can report progress on the shared progress bar (Id 0).
#
# IMPORTANT — how Connect-HPEGL reaches these functions:
# PowerShell nested modules each get their own session state; a PRIVATE function exported by one nested
# module is NOT resolvable from another nested module (only functions listed in the manifest's public
# FunctionsToExport become globally resolvable). Because Connect-HPEGL lives in Utilities.psm1 (a
# different nested module) and these helpers must stay hidden from end users, Utilities.psm1
# DOT-SOURCES this file (. "$PSScriptRoot\Auth-SSO.psm1") so the three flow functions are defined
# directly in Utilities' own session state and Connect-HPEGL can call them locally.
#
# This file therefore intentionally has NO Export-ModuleMember: an Export-ModuleMember call breaks the
# dot-source (it is only valid inside a module import and aborts the dot-source before the functions
# persist). The manifest FunctionsToExport does NOT list these functions, so they remain hidden from
# end users regardless.
#--------------------------------------------------------------------------------------------------------------------------------------------------------------------

function Update-ProgressBar {
    param (
        [int]$CompletedSteps,
        [int]$TotalSteps,
        [string]$CurrentActivity,
        [int]$Id
    )

    if (-not $NoProgress) {
        # Ensure percentage is between 0 and 100 (prevent negative values)
        $percentComplete = [math]::Max(0, [math]::Min(($CompletedSteps / $TotalSteps) * 100, 100))
        Write-Progress -Id $Id -Activity "Connecting to HPE GreenLake, please wait..." -Status $CurrentActivity -PercentComplete $percentComplete
    }
}

function Format-HPERedactedText {
    <#
    .DESCRIPTION
    Masks email addresses and sign-in session values (identity-provider tokens, SAML messages,
    authorization codes) in text that is written to the verbose/diagnostic stream so that a
    captured log can be shared for support without exposing the user's identity or a live sign-in. Handles both
    the plain form ('user@example.com') and the URL-encoded form ('user%40example.com'), including
    addresses embedded in URLs and JSON payloads. The first character of the local part and the
    top-level domain are kept so that two different accounts remain distinguishable in a log.
    Display only - never applied to data that is sent to an API.

    NOTE: an identical copy lives in Utilities.psm1 (nested modules do not share private functions).
    Keep both copies in sync.
    #>
    param([string]$Text)

    if ([string]::IsNullOrEmpty($Text)) { return $Text }

    $evaluator = {
        param($m)
        '{0}***@***.{1}' -f $m.Groups['local'].Value.Substring(0, 1), $m.Groups['tld'].Value
    }

    # URL-encoded form first ('%40'), then the plain form. The masked output contains no character
    # that either pattern can match again, so the function is safe to apply more than once.
    $out = [regex]::Replace($Text, '(?<local>[A-Za-z0-9._+\-]+)%40(?<domain>[A-Za-z0-9.\-]+\.)(?<tld>[A-Za-z]{2,})', $evaluator)
    $out = [regex]::Replace($out, '(?<local>[A-Za-z0-9._%+\-]+)@(?<domain>[A-Za-z0-9.\-]+\.)(?<tld>[A-Za-z]{2,})', $evaluator)

    # Sign-in session values (Entra ID flow token, canary and request context, Okta state token and handle,
    # SAML messages, authorization codes). They are short-lived, but they belong to a live sign-in and add
    # nothing to a support log. Masked as JSON values, as form/query parameters, and as hidden form inputs.
    # No closing quote is required, so a value cut short by a truncated log line is masked too.
    $out = [regex]::Replace($out, '(?i)("(?:flowToken|sFT|canary|apiCanary|originalRequest|sCtx|ctx|stateToken|stateHandle|SessionIdentifier|SAMLResponse|SAMLRequest|RelayState|csrfToken)"\s*:\s*")[^"]*', '$1[REDACTED]')
    $out = [regex]::Replace($out, '(?i)((?:^|[?&\s])(?:flowToken|sFT|canary|apiCanary|originalRequest|sCtx|ctx|stateToken|SessionIdentifier|SAMLResponse|SAMLRequest|RelayState|csrfToken|ppm_request|ppm_response|code)=)[^&\s"''<>]+', '$1[REDACTED]')
    $out = [regex]::Replace($out, '(?i)(name=["''](?:SAMLResponse|SAMLRequest|RelayState|flowToken|ctx|canary)["''][^>]*?value=["''])[^"'']*', '$1[REDACTED]')

    return $out
}

function Invoke-EntraIDSSOAuthentication {
    <#
            .SYNOPSIS
                Performs Entra ID (Azure AD) passwordless authentication using Microsoft Authenticator push notifications.

            .DESCRIPTION
                This function implements the correct Entra ID passwordless authentication flow:
                1. Calls GetCredentialType API to check available authentication methods
                2. Initiates push notification to Microsoft Authenticator app with number matching
                3. Polls DeviceCodeStatus API until user approves or denies the notification
                4. Returns the SAML response for completing HPE GreenLake authentication
                
                This flow does NOT require passwords and works with pure passwordless authentication policies.
                Only Microsoft Authenticator push notifications are supported in this passwordless flow.

            .PARAMETER StateToken
                The context token (ctx) from the SAML flow, used as originalRequest parameter

            .PARAMETER FlowToken
                The flow token from the Entra ID login page

            .PARAMETER CanaryToken
                The canary token for CSRF protection

            .PARAMETER Username
                The user's UPN (e.g., user@domain.onmicrosoft.com)

            .PARAMETER Session
                The WebRequestSession to maintain cookies and session state

            .PARAMETER TenantDomain
                The Entra ID tenant domain (e.g., login.microsoftonline.com)

            .PARAMETER BaseUrl
                The Entra ID base URL. Defaults to https://login.microsoftonline.com for commercial cloud.
                For sovereign clouds, specify: https://login.microsoftonline.us (Government), etc.    

            .PARAMETER NoProgress
                Suppresses progress bar updates (number matching entropy will still be shown)

            .PARAMETER CompletedSteps
                Reference to completed steps counter for progress tracking

            .PARAMETER TotalSteps
                Total number of steps for progress calculation

            .PARAMETER CurrentStep
                Reference to current step counter

            .PARAMETER Password
                Optional SecureString password for Entra ID password-based authentication.
                When provided, submits the password directly to the Entra ID login endpoint instead of
                initiating a Microsoft Authenticator push notification challenge.

            .EXAMPLE
                $result = Invoke-EntraIDSSOAuthentication -StateToken $ctx -FlowToken $flowToken `
                    -CanaryToken $canary -Username "user@domain.com" -Session $session -TenantDomain "login.microsoftonline.com"

                This example performs Entra ID passwordless authentication in the commercial cloud.

            .EXAMPLE
                $result = Invoke-EntraIDSSOAuthentication -StateToken $ctx -FlowToken $flowToken `
                    -CanaryToken $canary -Username "user@domain.com" -Session $session `
                    -TenantDomain "login.microsoftonline.us" -BaseUrl "https://login.microsoftonline.us"      
                    
                This example performs Entra ID passwordless authentication in the Azure Government cloud.

            .NOTES
                Passwordless sign-in uses Microsoft Authenticator push (number matching) only — TOTP is not a
                passwordless primary method in Entra ID. For password + MFA (step-up) accounts, both Microsoft
                Authenticator push (PhoneAppNotification) and one-time code / TOTP (PhoneAppOTP) are supported.
            #>

    param(
        [Parameter(Mandatory = $false)]
        [string]$StateToken,

        [Parameter(Mandatory = $false)]
        [string]$FlowToken,

        [Parameter(Mandatory = $false)]
        [string]$CanaryToken,

        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

        [Parameter(Mandatory = $true)]
        [string]$TenantDomain,

        [Parameter(Mandatory = $false)]
        [switch]$NoProgress,

        [Parameter(Mandatory = $false)]
        [ref]$CompletedSteps,

        [Parameter(Mandatory = $false)]
        [int]$TotalSteps,

        [Parameter(Mandatory = $false)]
        [ref]$CurrentStep,

        [Parameter(Mandatory = $false)]
        [string]$BaseUrl = "https://login.microsoftonline.com",

        [Parameter(Mandatory = $false)]
        [int]$TimeoutMinutes = 2,

        [Parameter(Mandatory = $false)]
        [int]$PollIntervalSeconds = 3,

        [Parameter(Mandatory = $false)]
        [SecureString]$Password
    )

    $functionName = "Invoke-EntraIDSSOAuthentication".ToUpper()
    $script:HelpUrl = "https://github.com/jullienl/HPE-COM-PowerShell-Library/blob/main/README.md"


    # Validate we have at least one required token
    if (-not $StateToken -and -not $FlowToken) {
        Write-Error "Either StateToken (ctx) or FlowToken must be provided for Entra ID authentication" -ErrorAction Stop
    }

    "[{0}] Starting Entra ID passwordless authentication" -f $functionName | Write-Verbose
    "[{0}] Username: {1}" -f $functionName, (Format-HPERedactedText -Text $Username) | Write-Verbose

    # Single progress bar update for the entire MFA process.
    # Label reflects the auth mode: a supplied password means password-based SSO, otherwise passwordless (push/TOTP).
    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
        $currentStepValue = $CurrentStep.Value
        $entraAuthModeLabel = if ($Password) { "Entra ID Password Authentication" } else { "Entra ID Passwordless Authentication" }
        Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps -CurrentActivity "Step $currentStepValue/$TotalSteps - $entraAuthModeLabel" -Id 0
        $CurrentStep.Value++
    }

    #Region STEP 1: Get Available Authentication Methods
                
    $getCredentialTypeUrl = "$baseUrl/common/GetCredentialType"

    "[{0}] Step 1: Checking available authentication methods using POST {1}" -f $functionName, $getCredentialTypeUrl | Write-Verbose
                
    # Detect country code with fallback
    $countryCode = try { 
        [System.Globalization.RegionInfo]::CurrentRegion.TwoLetterISORegionName 
    }
    catch { 
        "US" 
    }

    $payload = @{
        username                       = $Username
        isOtherIdpSupported            = $true
        checkPhones                    = $false
        isRemoteNGCSupported           = $true
        isCookieBannerShown            = $false
        isFidoSupported                = $true
        originalRequest                = $StateToken
        country                        = $countryCode
        forceotclogin                  = $false
        isExternalFederationDisallowed = $false
        isRemoteConnectSupported       = $false
        federationFlags                = 0
        isSignup                       = $false
        flowToken                      = $FlowToken
        isAccessPassSupported          = $true
        isQrCodePinSupported           = $true
    } | ConvertTo-Json -Depth 10

    $headers = @{
        "Content-Type"      = "application/json"
        "canary"            = $CanaryToken
        "client-request-id" = [guid]::NewGuid().ToString()             
    }

    "[{0}] Payload: `n{1}" -f $functionName, (Format-HPERedactedText -Text $payload) | Write-Verbose
    "[{0}] Headers: `n{1}" -f $functionName, ($headers | ConvertTo-Json -Depth 10) | ForEach-Object { Format-HPERedactedText -Text $_ } | Write-Verbose

    try {
        $credentialTypeResponse = Invoke-RestMethod -Uri $getCredentialTypeUrl -Method POST -ErrorAction Stop `
            -Headers $headers -Body $payload -WebSession $Session


        "[{0}] GetCredentialType response received: `n{1}" -f $functionName, (Format-HPERedactedText -Text ($credentialTypeResponse | ConvertTo-Json -Depth 10)) | Write-Verbose
    }
    catch {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
        }
        "[{0}] Failed to get credential type: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
        Write-Error "Could not retrieve Entra ID authentication methods. $($_.Exception.Message)" -ErrorAction Stop
    }

    # Update tokens if new ones were returned
    if ($credentialTypeResponse.FlowToken) {
        $FlowToken = $credentialTypeResponse.FlowToken
    }
    if ($credentialTypeResponse.apiCanary) {
        $CanaryToken = $credentialTypeResponse.apiCanary
    }
    #EndRegion STEP 1

    #Region STEP 2: Validate User and Check Authentication Methods
    "[{0}] Step 2: Validating user and authentication methods" -f $functionName | Write-Verbose

    # Check if user exists
    if ($credentialTypeResponse.IfExistsResult -ne 0) {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
        }
        Write-Error @"
User authentication failed.

This error can occur for multiple reasons:

1. User account does not exist in Entra ID
2. User account is disabled or locked
3. User is not assigned to the HPE GreenLake application in Entra ID
   - Contact your Entra ID administrator to verify application access
   - Ensure you have the required app role assignments

For complete Entra ID setup prerequisites, see: $script:HelpUrl
"@ -ErrorAction Stop
    }

    # Check throttle status
    if ($credentialTypeResponse.ThrottleStatus -eq 1) {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
        }
        Write-Error "Authentication requests are being throttled. Please wait a few minutes and try again." -ErrorAction Stop
    }

    # If no password was provided (i.e. called via -PasswordlessSSOEmail) but the account requires
    # a password (no passwordless method configured in Entra ID), fail with an actionable error.
    # Never prompt interactively — -PasswordlessSSOEmail must not block automation.
    if (-not $Password -and
        $credentialTypeResponse.Credentials -and
        -not $credentialTypeResponse.Credentials.HasRemoteNGC -and
        $credentialTypeResponse.Credentials.HasPassword) {
        "[{0}] Entra ID account requires a password but -PasswordlessSSOEmail was used — returning error." -f $functionName | Write-Verbose
        if (-not $NoProgress) {
            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Completed
        }
        # The IdP confirmed this account is password-based — record the rejection as password-based for telemetry.
        $Global:HPESSOPasswordSubmitted = $true
        Write-Error @"
Authentication failed: '$Username' is configured for password-based authentication in Entra ID, not passwordless.

Your Identity Provider (Entra ID) requires a password for this account.
Use -Credential instead:

   `$cred = Get-Credential -UserName '$Username'
   Connect-HPEGL -Credential `$cred
"@ -ErrorAction Stop
    }

    # If a password was provided via -Credential but the account uses passwordless authentication,
    # ignore the password and fall through to the push/TOTP flow (consistent with Okta and PingID).
    # Two cases qualify:
    #   1. HasPassword=false, HasRemoteNGC=true — purely passwordless account (no password enrolled).
    #   2. HasRemoteNGC=true with RemoteNgcParams populated — Entra pre-issued a passwordless phone
    #      sign-in challenge (Authenticator enrolled for passwordless). The verified DeviceCodeStatus
    #      push flow handles this, so the supplied password is not needed.
    # For password+MFA accounts (e.g. LynneR), RemoteNgcParams is null here (the push challenge is
    # only generated after the password step), so the password path is taken instead.
    if ($Password -and
        $credentialTypeResponse.Credentials -and
        $credentialTypeResponse.Credentials.HasRemoteNGC -and
        (-not $credentialTypeResponse.Credentials.HasPassword -or
        $credentialTypeResponse.Credentials.RemoteNgcParams)) {
        "[{0}] Entra ID account uses passwordless authentication (HasRemoteNGC=true, RemoteNgcParams pre-populated) — ignoring provided password and using push/TOTP flow." -f $functionName | Write-Verbose
        Write-Warning @"
Your Entra ID account uses passwordless authentication. The provided password will not be used — attempting SSO (push/TOTP) authentication instead.
To avoid this warning, use -PasswordlessSSOEmail instead of -Credential.
"@
        $Password = $null
    }

    # Password authentication path — submit credentials directly to login endpoint
    if ($Password) {
        "[{0}] Password provided — using Entra ID password authentication" -f $functionName | Write-Verbose

        # Determine tenant login URL (use tenant UUID from StateToken when available)
        $loginTenantId = "common"
        if ($StateToken -and $StateToken -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
            $loginTenantId = $matches[1]
        }
        $loginUrl = "$BaseUrl/$loginTenantId/login"

        # Decrypt SecureString to plaintext — cleared immediately after use
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        try {
            $passwordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        }
        finally {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }

        $formData = @(
            "login=$([uri]::EscapeDataString($Username))"
            "passwd=$([uri]::EscapeDataString($passwordPlainText))"
            "type=11"
            "ctx=$([uri]::EscapeDataString($StateToken))"
            "flowToken=$([uri]::EscapeDataString($FlowToken))"
            "canary=$([uri]::EscapeDataString($CanaryToken))"
        ) -join '&'
        $passwordPlainText = $null

        $loginHeaders = @{ "Content-Type" = "application/x-www-form-urlencoded" }

        "[{0}] POSTing password credentials to: {1}" -f $functionName, $loginUrl | Write-Verbose

        try {
            # Password is about to be submitted to Entra ID — flag this connection as genuinely
            # password-based for telemetry (set before the POST so a rejected/bad password still counts).
            $Global:HPESSOPasswordSubmitted = $true
            $loginResponse = Invoke-WebRequest -Uri $loginUrl -Method POST -Body $formData `
                -Headers $loginHeaders -ErrorAction Stop -WebSession $Session -MaximumRedirection 10

            "[{0}] Password login POST completed (status {1})" -f $functionName, $loginResponse.StatusCode | Write-Verbose

            # Detect explicit error codes in page body
            if ($loginResponse.Content -match '"sErrorCode"\s*:\s*"([^"]+)"' -or
                $loginResponse.Content -match '"arrValErrs"\s*:\s*\[' -or
                $loginResponse.Content -match 'AADSTS[0-9]+') {
                $errCode = if ($Matches[1]) { $Matches[1] } else { "unknown" }
                "[{0}] Entra ID returned an error code: {1}" -f $functionName, $errCode | Write-Verbose
                Write-Error "Invalid password or Entra ID policy rejected the credential (error: $($errCode))" -ErrorAction Stop
            }

            # SAML response already in page
            if ($loginResponse.Content -match 'name="SAMLResponse"') {
                "[{0}] SAML response found directly in password login response" -f $functionName | Write-Verbose
                if ($CompletedSteps) { $CompletedSteps.Value++ }
                return $loginResponse
            }

            # KMSI (Keep Me Signed In) interstitial page
            $isKmsiPage = $loginResponse.Content -match '"PageID"\s*content="KmsiInterrupt"' -or
            $loginResponse.Content -match '"urlPost"\s*:\s*"/kmsi"'
            if ($isKmsiPage) {
                "[{0}] KMSI page detected after password login" -f $functionName | Write-Verbose

                $kmsiCtx = ""
                $kmsiFlowToken = ""
                $kmsiCanary = ""

                if ($loginResponse.Content -match '"sFT"\s*:\s*"([^"]+)"') { $kmsiFlowToken = $matches[1] }
                if ($loginResponse.Content -match '"sCtx"\s*:\s*"([^"]+)"') { $kmsiCtx = $matches[1] }
                elseif ($StateToken) { $kmsiCtx = $StateToken }
                if ($loginResponse.Content -match '"canary"\s*:\s*"([^"]+)"') { $kmsiCanary = $matches[1] }

                $kmsiUrl = "$BaseUrl/kmsi"
                $kmsiFormData = @(
                    "LoginOptions=1"
                    "type=28"
                    "ctx=$([uri]::EscapeDataString($kmsiCtx))"
                    "flowToken=$([uri]::EscapeDataString($kmsiFlowToken))"
                    "canary=$([uri]::EscapeDataString($kmsiCanary))"
                ) -join '&'

                $kmsiResponse = Invoke-WebRequest -Uri $kmsiUrl -Method POST -Body $kmsiFormData `
                    -Headers $loginHeaders -ErrorAction Stop -WebSession $Session -MaximumRedirection 10

                "[{0}] KMSI POST completed after password login" -f $functionName | Write-Verbose
                if ($CompletedSteps) { $CompletedSteps.Value++ }
                return $kmsiResponse
            }

            # --- Step-up MFA detection ---
            # Conditional Access requires MFA after password. Entra ID returns a new challenge
            # page with RemoteNgcParams (push) data instead of a SAML response.
            $stepUpSessionId = $null
            $stepUpEntropy = $null

            # Try to extract RemoteNgcParams from JSON embedded in the page
            if ($loginResponse.Content -match '"SessionIdentifier"\s*:\s*"([^"]+)"') {
                $stepUpSessionId = $matches[1]
            }
            if ($loginResponse.Content -match '"Entropy"\s*:\s*(\d+)') {
                $stepUpEntropy = [int]$matches[1]
            }

            # Also extract updated flow tokens for the push polling call
            if ($loginResponse.Content -match '"sFT"\s*:\s*"([^"]+)"') { $FlowToken = $matches[1] }
            if ($loginResponse.Content -match '"apiCanary"\s*:\s*"([^"]+)"') { $CanaryToken = $matches[1] }
            elseif ($loginResponse.Content -match '"canary"\s*:\s*"([^"]+)"') { $CanaryToken = $matches[1] }

            if ($stepUpSessionId) {
                "[{0}] Step-up MFA required after password — Microsoft Authenticator push initiated" -f $functionName | Write-Verbose
                $sessionIdentifier = $stepUpSessionId
                $entropy = $stepUpEntropy
                $mfaRequired = $true
                # Fall through to STEP 3 (push polling) below — do NOT return here
            }
            else {
                # Check if this is a step-up MFA challenge page requiring the SAS push-notification API
                # (Conditional Access MFA after password — Entra returns new sFT/sCtx but no SessionIdentifier)
                if ($loginResponse.Content -match '"sFT"\s*:\s*"([^"]+)"') {
                    "[{0}] SAS step-up MFA challenge page detected after password login" -f $functionName | Write-Verbose
                    $sasMfaRequired = $true
                    # Refresh sCtx (StateToken) from the step-up page if present
                    # Note: FlowToken and CanaryToken were already refreshed in the block above
                    if ($loginResponse.Content -match '"sCtx"\s*:\s*"([^"]+)"') { $StateToken = $matches[1] }

                    # Determine which second factor Entra expects from arrUserProofs on the challenge page.
                    # arrUserProofs lists the user's registered MFA methods; the default one (isDefault=true)
                    # is the method the browser auto-selects:
                    #   PhoneAppNotification = Microsoft Authenticator push (approve / number matching)
                    #   PhoneAppOTP          = Microsoft Authenticator one-time code (TOTP — user types a 6-digit code)
                    $sasAuthMethodId = "PhoneAppNotification"   # default to push (existing, well-tested behaviour)
                    if ($loginResponse.Content -match '"arrUserProofs"\s*:\s*\[([\s\S]*?)\]') {
                        $proofsBlock = $matches[1]
                        "[{0}] arrUserProofs: {1}" -f $functionName, $proofsBlock | Write-Verbose
                        if ($proofsBlock -match '"authMethodId"\s*:\s*"([^"]+)"[^}]*"isDefault"\s*:\s*true') {
                            $sasAuthMethodId = $matches[1]
                        }
                        elseif ($proofsBlock -match '"isDefault"\s*:\s*true[^}]*"authMethodId"\s*:\s*"([^"]+)"') {
                            $sasAuthMethodId = $matches[1]
                        }
                        elseif ($proofsBlock -match '"authMethodId"\s*:\s*"([^"]+)"') {
                            $sasAuthMethodId = $matches[1]
                        }
                    }
                    "[{0}] SAS step-up second factor selected: {1}" -f $functionName, $sasAuthMethodId | Write-Verbose
                }
                else {
                    # Truly unrecognised — return whatever we got
                    "[{0}] Password login response type unrecognised — returning raw response" -f $functionName | Write-Verbose
                    if ($CompletedSteps) { $CompletedSteps.Value++ }
                    return $loginResponse
                }
            }
        }
        catch {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
            }
            "[{0}] Entra ID password authentication failed: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
            Write-Error "Authentication failed: Entra ID rejected the credentials for '$Username'. Verify username and password. Error: $($_.Exception.Message)" -ErrorAction Stop
        }
    }
    # End password path

    #Region SAS step-up MFA flow (password accepted; Entra ID requires a second factor via SAS API)
    # SAS = Step-up Authentication Service: Entra ID internal API used to handle the second-factor MFA challenge after a successful primary credential (password) submission, when Conditional Access requires additional verification
    # This path is taken when GetCredentialType reported HasPassword=true but no RemoteNgcParams,
    # and the Conditional Access policy demands an additional MFA challenge after the password succeeds.
    # The method is chosen from arrUserProofs ($sasAuthMethodId):
    #   PhoneAppNotification (push):  BeginAuth → EndAuth (GET poll) → ProcessAuth (type=22) → KMSI (optional) → SAMLResponse
    #   PhoneAppOTP (TOTP code):      BeginAuth → EndAuth (POST, AdditionalAuthData=code) → ProcessAuth (type=19, otc=code) → KMSI (optional) → SAMLResponse
    if ($sasMfaRequired) {

        # Fall back to push if detection didn't run for any reason
        if (-not $sasAuthMethodId) { $sasAuthMethodId = "PhoneAppNotification" }

        # ── A. Initiate the second-factor challenge via SAS/BeginAuth ───────────────
        "[{0}] SAS step-up: calling BeginAuth (AuthMethodId={1})" -f $functionName, $sasAuthMethodId | Write-Verbose

        $sasBeginAuthUrl = "$baseUrl/common/SAS/BeginAuth"
        $sasBeginAuthPayload = @{
            AuthMethodId = $sasAuthMethodId
            Method       = "BeginAuth"
            ctx          = $StateToken
            flowToken    = $FlowToken
        } | ConvertTo-Json -Depth 10

        $sasBeginAuthHeaders = @{
            "Content-Type"      = "application/json"
            "canary"            = $CanaryToken
            "client-request-id" = [guid]::NewGuid().ToString()
        }

        try {
            $sasBeginAuthResponse = Invoke-RestMethod -Uri $sasBeginAuthUrl -Method POST -ErrorAction Stop `
                -Headers $sasBeginAuthHeaders -Body $sasBeginAuthPayload -WebSession $Session

            "[{0}] SAS BeginAuth response: `n{1}" -f $functionName, ($sasBeginAuthResponse | ConvertTo-Json -Depth 10) | ForEach-Object { Format-HPERedactedText -Text $_ } | Write-Verbose
        }
        catch {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
            }
            "[{0}] SAS BeginAuth failed: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
            Write-Error "Could not initiate Microsoft Authenticator push notification. $($_.Exception.Message)" -ErrorAction Stop
        }

        # Capture FlowToken update from BeginAuth (required for ProcessAuth)
        $sasFlowToken = if ($sasBeginAuthResponse.FlowToken) { $sasBeginAuthResponse.FlowToken } else { $FlowToken }
        $sasEntropy = if ($sasBeginAuthResponse.Entropy) { $sasBeginAuthResponse.Entropy }   else { $null }

        if ($sasAuthMethodId -eq 'PhoneAppOTP') {
            # ===== TOTP (Authenticator one-time code) branch =====
            # No push and no polling — the user reads the current 6-digit code from their
            # authenticator app. A single EndAuth POST submits the code (AdditionalAuthData),
            # then ProcessAuth (type=19, otc=<code>) finalises MFA.
            "[{0}] SAS step-up: TOTP (PhoneAppOTP) — prompting for one-time code" -f $functionName | Write-Verbose

            # Hide the progress bar so the prompt is clearly visible
            if (-not $NoProgress) { Write-Progress -Id 0 -Activity "Entra ID Authentication" -Completed }

            $totpCode = Read-Host -Prompt "Enter the verification code from your authenticator app for $Username"
            $totpCode = ($totpCode -replace '\s', '')

            if ([string]::IsNullOrWhiteSpace($totpCode)) {
                Write-Error "No verification code entered. Authentication cannot proceed." -ErrorAction Stop
            }

            $sasSessionId = $sasBeginAuthResponse.SessionId
            $sasLastPollStart = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

            $sasEndAuthUrl = "$baseUrl/common/SAS/EndAuth"
            $sasEndAuthBody = @{
                Method             = "EndAuth"
                SessionId          = $sasSessionId
                FlowToken          = $sasFlowToken
                Ctx                = $StateToken
                AuthMethodId       = "PhoneAppOTP"
                AdditionalAuthData = $totpCode
                PollCount          = 1
            } | ConvertTo-Json -Depth 10

            $sasEndAuthHeaders = @{
                "Accept"            = "application/json"
                "Content-type"      = "application/json; charset=utf-8"
                "canary"            = $CanaryToken
                "client-request-id" = [guid]::NewGuid().ToString()
            }

            try {
                $sasEndAuthResponse = Invoke-RestMethod -Uri $sasEndAuthUrl -Method POST `
                    -Body $sasEndAuthBody -Headers $sasEndAuthHeaders -ErrorAction Stop -WebSession $Session

                $sasLastPollEnd = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

                "[{0}] SAS EndAuth (TOTP) response: `n{1}" -f $functionName, ($sasEndAuthResponse | ConvertTo-Json -Depth 10) | ForEach-Object { Format-HPERedactedText -Text $_ } | Write-Verbose

                # Refresh tokens from the EndAuth response when present
                if ($sasEndAuthResponse.FlowToken) { $sasFlowToken = $sasEndAuthResponse.FlowToken }
                if ($sasEndAuthResponse.Ctx) { $StateToken = $sasEndAuthResponse.Ctx }

                # A clear non-zero error code (other than the "pending" 500121) means the code was rejected
                if ($sasEndAuthResponse.Success -ne $true -and
                    $sasEndAuthResponse.ErrCode -and
                    [int]$sasEndAuthResponse.ErrCode -ne 0 -and
                    [int]$sasEndAuthResponse.ErrCode -ne 500121) {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                    }
                    "[{0}] TOTP code rejected (ErrCode={1}, Message={2})" -f $functionName, $sasEndAuthResponse.ErrCode, $sasEndAuthResponse.Message | Write-Verbose
                    Write-Error "Authentication failed: The verification code was rejected by Entra ID. Verify the current code in your authenticator app and try again." -ErrorAction Stop
                }

                "[{0}] TOTP code submitted — completing via ProcessAuth" -f $functionName | Write-Verbose
            }
            catch {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                }
                "[{0}] SAS EndAuth (TOTP) failed: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                Write-Error "Could not verify the authenticator code. $($_.Exception.Message)" -ErrorAction Stop
            }
        }
        else {

            # ── B. Prompt user ────────────────────────────────────────────────────────────
            Start-Sleep -Milliseconds 500

            if ($sasEntropy -and $sasEntropy -gt 0) {
                if ($NoProgress) {
                    Write-Host "`n  Action required: Open Microsoft Authenticator and enter the number " -NoNewline -ForegroundColor Cyan
                    Write-Host $sasEntropy -ForegroundColor Yellow -NoNewline
                    Write-Host " to authenticate.`n" -ForegroundColor Cyan
                }
                elseif ($CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                        -CurrentActivity "Respond '$sasEntropy' to the Microsoft Authenticator notification" -Id 0
                }
                "[{0}] SAS number matching active — user must enter: {1}" -f $functionName, $sasEntropy | Write-Verbose
            }
            else {
                if ($NoProgress) {
                    Write-Host "`n  Action required: Open Microsoft Authenticator on your phone and approve the sign-in request.`n" -ForegroundColor Cyan
                }
                elseif ($CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                        -CurrentActivity "Approve the Microsoft Authenticator push notification on your phone" -Id 0
                }
            }

            # ── C. Poll SAS/EndAuth until the user approves (or timeout) ─────────────────
            "[{0}] SAS step-up: polling SAS/EndAuth for approval" -f $functionName | Write-Verbose

            $sasEndAuthBaseUrl = "$baseUrl/common/SAS/EndAuth"
            $sasSessionId = $sasBeginAuthResponse.SessionId

            $sasTimeout = [datetime]::Now.AddMinutes($TimeoutMinutes)
            $sasPollCount = 0
            $sasMaxPolls = 120
            $sasApproved = $false
            $sasLastPollStart = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
            $sasLastPollEnd = $sasLastPollStart

            do {
                $sasPollCount++
                $sasLastPollStart = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

                $sasEndAuthQuery = "authMethodId=PhoneAppNotification&pollCount=$sasPollCount"
                if ($sasPollCount -gt 1) {
                    $sasEndAuthQuery += "&lastPollStart=$sasLastPollStart&lastPollEnd=$sasLastPollEnd"
                }

                # These three x-ms-* headers are required so Entra ID can identify the active MFA session
                $sasEndAuthHeaders = @{
                    "Accept"            = "application/json"
                    "Content-type"      = "application/json; charset=utf-8"
                    "canary"            = $CanaryToken
                    "client-request-id" = [guid]::NewGuid().ToString()
                    "x-ms-sessionId"    = $sasSessionId
                    "x-ms-flowToken"    = $sasFlowToken
                    "x-ms-ctx"          = $StateToken
                }

                try {
                    $sasEndAuthResponse = Invoke-RestMethod -Uri "$sasEndAuthBaseUrl`?$sasEndAuthQuery" `
                        -Method GET -Headers $sasEndAuthHeaders -ErrorAction Stop -WebSession $Session

                    $sasLastPollEnd = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

                    "[{0}] SAS EndAuth poll #{1}: Success={2}, ErrCode={3}, Retry={4}" -f $functionName, $sasPollCount, $sasEndAuthResponse.Success, $sasEndAuthResponse.ErrCode, $sasEndAuthResponse.Retry | Write-Verbose

                    # Approved — break out of polling loop
                    if ($sasEndAuthResponse.Success -eq $true) {
                        $sasApproved = $true
                        if ($sasEndAuthResponse.FlowToken) { $sasFlowToken = $sasEndAuthResponse.FlowToken }
                        if ($sasEndAuthResponse.Ctx) { $StateToken = $sasEndAuthResponse.Ctx }
                        "[{0}] SAS push notification approved by user" -f $functionName | Write-Verbose
                        break
                    }

                    # Microsoft signals "keep polling" via Retry=true. Once the result is terminal
                    # (user approves/denies, number mismatch, timeout on Entra side), Retry becomes false.
                    #   - ErrCode 500121 + Retry=true  = MFA challenge still pending -> keep polling
                    #   - ErrCode 500121 + Retry=false = push was denied / number mismatch -> terminal failure
                    #   - Any other non-zero ErrCode with Success=false = terminal failure
                    if ($sasEndAuthResponse.Success -eq $false -and
                        $sasEndAuthResponse.ErrCode -ne 0 -and
                        ($sasEndAuthResponse.ErrCode -ne 500121 -or $sasEndAuthResponse.Retry -eq $false)) {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                        }
                        "[{0}] SAS push notification denied or failed (ErrCode={1}, Retry={2}, Message={3})" -f $functionName, $sasEndAuthResponse.ErrCode, $sasEndAuthResponse.Retry, $sasEndAuthResponse.Message | Write-Verbose
                        Write-Error "Microsoft Authenticator push notification was denied. Please try again and approve the request on your phone." -ErrorAction Stop
                    }
                    # else: ErrCode=0 with Retry=true, or ErrCode=500121 with Retry=true — still pending, fall through to sleep and retry
                }
                catch {
                    if ($_.Exception.Message -notmatch "timeout|timed out") {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                        }
                        throw
                    }
                }

                if ([datetime]::Now -ge $sasTimeout) {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                    }
                    Write-Error @"
Timeout! Microsoft Authenticator push notification was not approved within $TimeoutMinutes minutes.

Please try again and approve the request promptly.
"@ -ErrorAction Stop
                }

                Start-Sleep -Seconds $PollIntervalSeconds

            } until ($sasApproved -or $sasPollCount -ge $sasMaxPolls)

            if (-not $sasApproved) {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                }
                Write-Error "Push notification approval failed or timed out. Please try again." -ErrorAction Stop
            }
        }
        # End push branch

        # ── D. Complete MFA via SAS/ProcessAuth ──────────────────────────────────────
        "[{0}] SAS step-up: calling ProcessAuth to complete MFA" -f $functionName | Write-Verbose

        $sasProcessAuthUrl = "$baseUrl/common/SAS/ProcessAuth"
        $sasI19 = $sasLastPollEnd - $sasLastPollStart
        if ($sasAuthMethodId -eq 'PhoneAppOTP') {
            # TOTP: type=19, carry the one-time code as otc, plus GeneralVerify=false
            $sasProcessAuthBody = @(
                "type=19"
                "GeneralVerify=false"
                "request=$([uri]::EscapeDataString($StateToken))"
                "mfaLastPollStart=$sasLastPollStart"
                "mfaLastPollEnd=$sasLastPollEnd"
                "mfaAuthMethod=PhoneAppOTP"
                "otc=$([uri]::EscapeDataString($totpCode))"
                "login=$([uri]::EscapeDataString($Username))"
                "flowToken=$([uri]::EscapeDataString($sasFlowToken))"
                "canary=$([uri]::EscapeDataString($CanaryToken))"
                "hpgrequestid=$([guid]::NewGuid().ToString())"
                "sacxt="
                "hideSmsInMfaProofs=false"
                "i19=$sasI19"
            ) -join '&'
        }
        else {
            $sasProcessAuthBody = @(
                "type=22"
                "request=$([uri]::EscapeDataString($StateToken))"
                "mfaLastPollStart=$sasLastPollStart"
                "mfaLastPollEnd=$sasLastPollEnd"
                "mfaAuthMethod=PhoneAppNotification"
                "login=$([uri]::EscapeDataString($Username))"
                "flowToken=$([uri]::EscapeDataString($sasFlowToken))"
                "canary=$([uri]::EscapeDataString($CanaryToken))"
                "hpgrequestid=$([guid]::NewGuid().ToString())"
                "sacxt="
                "hideSmsInMfaProofs=false"
                "i19=$sasI19"
            ) -join '&'
        }

        $sasProcessAuthHeaders = @{ "Content-Type" = "application/x-www-form-urlencoded" }

        try {
            $sasProcessAuthResponse = Invoke-WebRequest -Uri $sasProcessAuthUrl -Method POST `
                -Body $sasProcessAuthBody -Headers $sasProcessAuthHeaders `
                -ErrorAction Stop -WebSession $Session -MaximumRedirection 10

            "[{0}] SAS ProcessAuth completed (status {1})" -f $functionName, $sasProcessAuthResponse.StatusCode | Write-Verbose

            # SAML response in ProcessAuth response — done
            if ($sasProcessAuthResponse.Content -match 'name="SAMLResponse"') {
                "[{0}] SAML response found in SAS ProcessAuth response" -f $functionName | Write-Verbose
                $Global:HPEEntraStepUpMfaSucceeded = $true
                if ($CompletedSteps) { $CompletedSteps.Value++ }
                return $sasProcessAuthResponse
            }

            # KMSI interstitial page
            $sasIsKmsi = $sasProcessAuthResponse.Content -match '"PageID"\s*content="KmsiInterrupt"' -or
            $sasProcessAuthResponse.Content -match '"urlPost"\s*:\s*"/kmsi"'

            if ($sasIsKmsi) {
                "[{0}] KMSI page detected after SAS ProcessAuth" -f $functionName | Write-Verbose

                $sasKmsiCtx = if ($sasProcessAuthResponse.Content -match '"sCtx"\s*:\s*"([^"]+)"') { $matches[1] } else { $StateToken }
                $sasKmsiFlowToken = if ($sasProcessAuthResponse.Content -match '"sFT"\s*:\s*"([^"]+)"') { $matches[1] } else { $sasFlowToken }
                $sasKmsiCanary = if ($sasProcessAuthResponse.Content -match '"canary"\s*:\s*"([^"]+)"') { $matches[1] } else { $CanaryToken }

                $sasKmsiFormData = @(
                    "LoginOptions=1"
                    "type=28"
                    "ctx=$([uri]::EscapeDataString($sasKmsiCtx))"
                    "flowToken=$([uri]::EscapeDataString($sasKmsiFlowToken))"
                    "canary=$([uri]::EscapeDataString($sasKmsiCanary))"
                ) -join '&'

                $sasKmsiResponse = Invoke-WebRequest -Uri "$baseUrl/kmsi" -Method POST `
                    -Body $sasKmsiFormData -Headers $sasProcessAuthHeaders `
                    -ErrorAction Stop -WebSession $Session -MaximumRedirection 10

                "[{0}] SAS KMSI POST completed" -f $functionName | Write-Verbose
                $Global:HPEEntraStepUpMfaSucceeded = $true
                if ($CompletedSteps) { $CompletedSteps.Value++ }
                return $sasKmsiResponse
            }

            # OIDC federation: when no KMSI page follows, a successful ProcessAuth redirects straight back to HPE (authorization
            # code), so the response is no longer an Entra ID page. A rejected code re-renders the Entra ID page instead.
            $sasFinalHost = try { $sasProcessAuthResponse.BaseResponse.RequestMessage.RequestUri.Host } catch { '' }
            if ($sasFinalHost -and $sasFinalHost -notmatch 'login\.microsoftonline\.com|login\.windows\.net|sts\.windows\.net|login\.live\.com') {
                "[{0}] SAS ProcessAuth redirected back to the application - authentication complete" -f $functionName | Write-Verbose
                $Global:HPEEntraStepUpMfaSucceeded = $true
                if ($CompletedSteps) { $CompletedSteps.Value++ }
                return $sasProcessAuthResponse
            }

            # For TOTP, a successful code always yields a SAML or KMSI response above.
            # Anything else means Entra ID re-rendered the MFA page because the code was
            # wrong/expired — surface a clear, actionable error instead of a generic one.
            if ($sasAuthMethodId -eq 'PhoneAppOTP') {
                $totpErrMsg = if ($sasProcessAuthResponse.Content -match '"strServiceExceptionMessage"\s*:\s*"([^"]+)"') { $matches[1] }
                elseif ($sasProcessAuthResponse.Content -match '"strMainMessage"\s*:\s*"([^"]+)"') { $matches[1] }
                elseif ($sasProcessAuthResponse.Content -match '"sErrorCode"\s*:\s*"([^"]+)"') { "error code $($matches[1])" }
                else { $null }
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                }
                "[{0}] TOTP ProcessAuth returned no SAML/KMSI — code rejected ({1})" -f $functionName, $totpErrMsg | Write-Verbose
                Write-Error "Authentication failed: The verification code was rejected by Entra ID. Verify the current code in your authenticator app and try again." -ErrorAction Stop
            }

            # Fallback — return whatever ProcessAuth returned
            $Global:HPEEntraStepUpMfaSucceeded = $true
            if ($CompletedSteps) { $CompletedSteps.Value++ }
            return $sasProcessAuthResponse
        }
        catch {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
            }
            "[{0}] SAS ProcessAuth failed: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
            # Do not re-wrap an already-actionable rejection (e.g. wrong TOTP code) raised inside the try.
            if ($_.Exception.Message -match '^Authentication failed:') {
                Write-Error $_.Exception.Message -ErrorAction Stop
            }
            Write-Error "Could not complete SAS MFA authentication. $($_.Exception.Message)" -ErrorAction Stop
        }
    }
    #EndRegion SAS step-up MFA flow

    # Extract authentication method details (skipped when step-up already set $sessionIdentifier)
    $sessionIdentifier = if ($Password -and $sessionIdentifier) { $sessionIdentifier } else { $null }
    $entropy = if ($Password -and $sessionIdentifier) { $entropy }           else { $null }

    if (-not $sessionIdentifier -and $credentialTypeResponse.Credentials) {
        # Check for RemoteNGC (push notification) support
        if ($credentialTypeResponse.Credentials.HasRemoteNGC) {
            if ($credentialTypeResponse.Credentials.RemoteNgcParams) {
                $sessionIdentifier = $credentialTypeResponse.Credentials.RemoteNgcParams.SessionIdentifier
                $entropy = $credentialTypeResponse.Credentials.RemoteNgcParams.Entropy

                $prefCredential = $credentialTypeResponse.Credentials.PrefCredential

                # Entra can flag the pre-armed push as blocked (e.g. a recent denied/"report suspicious activity"
                # response temporarily rate-limits Authenticator pushes). When blocked, no number-matching
                # challenge is issued, so RemoteNgcParams contains no Entropy.
                $isNotificationBlocked = [bool]$credentialTypeResponse.Credentials.RemoteNgcParams.IsNotificationBlocked

                "[{0}] Push notification available (PrefCredential={1}, IsNotificationBlocked={2}) - initial Entropy: {3}" -f $functionName, $prefCredential, $isNotificationBlocked, $entropy | Write-Verbose

                # Arm the passwordless push when it is NOT pre-armed by Entra.
                #
                # When PrefCredential=2 (RemoteNGC preferred) Entra normally pre-arms the push during
                # GetCredentialType: RemoteNgcParams.SessionIdentifier is already a LIVE device code,
                # so DeviceCodeStatus returns 0 (pending) until the user approves.
                #
                # When PrefCredential!=2 (password preferred — the usual case for a fresh WebSession
                # with -RemoveExistingCredentials) the push is NOT armed: RemoteNgcParams.SessionIdentifier
                # is inert and DeviceCodeStatus returns AuthorizationState=3 immediately, with no push
                # ever sent. In the browser this is the "Use an app instead" action, which issues
                # POST /common/GetOneTimeCode to arm the push and obtain a fresh, live SessionIdentifier
                # (+ Entropy). Replicate that here so the subsequent DeviceCodeStatus poll succeeds.
                # (Endpoint/request verified against a browser HAR capture of the PrefCredential=1 flow.)
                #
                # Even when PrefCredential=2, Entra may fail to pre-arm the push (no Entropy) or report
                # IsNotificationBlocked=true. In those cases attempt the same GetOneTimeCode arming as a
                # recovery — it can return a fresh, live SessionIdentifier and Entropy and clear the block.
                if ($prefCredential -ne 2 -or -not $entropy -or $isNotificationBlocked) {
                    "[{0}] Push not pre-armed (PrefCredential={1}, IsNotificationBlocked={2}, Entropy present={3}) - arming push via GetOneTimeCode" -f $functionName, $prefCredential, $isNotificationBlocked, [bool]$entropy | Write-Verbose

                    $getOneTimeCodeUrl = "$baseUrl/common/GetOneTimeCode"
                    $getOneTimeCodePayload = @{
                        Channel         = "Authenticator"
                        OriginalRequest = $StateToken
                        FlowToken       = $FlowToken
                        OldDeviceCode   = $credentialTypeResponse.Credentials.RemoteNgcParams.SessionIdentifier
                    } | ConvertTo-Json -Depth 10

                    $getOneTimeCodeHeaders = @{
                        "Accept"            = "application/json"
                        "Content-Type"      = "application/json; charset=UTF-8"
                        "canary"            = $CanaryToken
                        "client-request-id" = [guid]::NewGuid().ToString()
                        "hpgrequestid"      = [guid]::NewGuid().ToString()
                    }

                    try {
                        "[{0}] Calling GetOneTimeCode to dispatch the Microsoft Authenticator push" -f $functionName | Write-Verbose
                        $getOneTimeCodeResponse = Invoke-RestMethod -Uri $getOneTimeCodeUrl -Method POST -ErrorAction Stop `
                            -Headers $getOneTimeCodeHeaders -Body $getOneTimeCodePayload -WebSession $Session

                        "[{0}] GetOneTimeCode response: `n{1}" -f $functionName, ($getOneTimeCodeResponse | ConvertTo-Json -Depth 10) | ForEach-Object { Format-HPERedactedText -Text $_ } | Write-Verbose

                        # Replace the inert RemoteNgcParams code with the live armed values.
                        # Microsoft returns these under the same field names used elsewhere in this flow
                        # (RemoteNgcParams / SAS BeginAuth): SessionIdentifier, Entropy, FlowToken.
                        if ($getOneTimeCodeResponse.SessionIdentifier) {
                            $sessionIdentifier = $getOneTimeCodeResponse.SessionIdentifier
                            "[{0}] Push armed - using live SessionIdentifier from GetOneTimeCode" -f $functionName | Write-Verbose
                        }
                        if ($getOneTimeCodeResponse.Entropy) {
                            $entropy = $getOneTimeCodeResponse.Entropy
                        }
                        if ($getOneTimeCodeResponse.FlowToken) {
                            $FlowToken = $getOneTimeCodeResponse.FlowToken
                        }

                        "[{0}] Push armed - Entropy: {1}" -f $functionName, $entropy | Write-Verbose
                    }
                    catch {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                        }
                        "[{0}] GetOneTimeCode failed: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                        Write-Error "Could not initiate the Microsoft Authenticator push notification (GetOneTimeCode failed). $($_.Exception.Message)" -ErrorAction Stop
                    }
                }

                # Check if Entropy is missing even though RemoteNgcParams exists
                if (-not $entropy) {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                    }

                    # Re-read the blocked flag after the arming attempt — GetOneTimeCode may have cleared it.
                    if ($getOneTimeCodeResponse -and ($null -ne $getOneTimeCodeResponse.IsNotificationBlocked)) {
                        $isNotificationBlocked = [bool]$getOneTimeCodeResponse.IsNotificationBlocked
                    }

                    if ($isNotificationBlocked) {
                        "[{0}] Microsoft Authenticator push notifications are blocked (IsNotificationBlocked=true) - no Entropy issued" -f $functionName | Write-Verbose
                        $errorMessage = @"
Microsoft Entra ID reported that Microsoft Authenticator push notifications are currently blocked for '$Username'.

Because notifications are blocked, Entra ID did not issue a number-matching challenge, so no approval request can be sent to your phone.

This is usually a temporary state caused by one of the following:

1. A recent sign-in request was denied, or "Report suspicious activity" was tapped in
   Microsoft Authenticator. Entra ID temporarily blocks further push notifications after this.
   - Wait a few minutes, then retry Connect-HPEGL.

2. Too many push requests were sent in a short period (rate limiting).
   - Wait a few minutes, then retry.

3. An administrator has restricted or blocked Authenticator notifications for your account
   or via a Conditional Access / authentication-methods policy.
   - Contact your Entra ID administrator to confirm push approval is allowed.

If the block persists, verify your sign-in methods at https://aka.ms/mysecurityinfo and, if
available, use an alternative method (e.g. a verification code / TOTP from Microsoft Authenticator).

For complete Entra ID setup prerequisites, see: $script:HelpUrl
"@
                        Write-Error $errorMessage -ErrorAction Stop
                    }

                    "[{0}] RemoteNgcParams present but Entropy field is missing" -f $functionName | Write-Verbose
                    $errorMessage = @"
Microsoft Entra ID did not return an Entropy value for this authentication attempt.

This means Entra ID did not issue a number-matching challenge to Microsoft Authenticator.  
Number matching is required for this authentication flow, and when it is not triggered, the Entropy field is omitted.

One of the most common causes is that Microsoft Authenticator is enrolled for MFA but not fully enabled for passwordless phone sign-in.

Please verify the following:

1. Enable passwordless phone sign-in (critical)
   - Open Microsoft Authenticator on your mobile device
   - Tap your work account
   - Tap “Enable phone sign-in” or “Set up passwordless sign-in requests”
   - Complete the biometric setup and approval prompt
   - Confirm that “Passwordless sign-in requests” appears for your account

2. Check your authentication methods
   https://aka.ms/mysecurityinfo
   - Ensure you have BOTH:
       • Microsoft Authenticator - passwordless phone sign-in
       • Microsoft Authenticator - push MFA
   - Remove duplicate or stale entries

3. Check device registration
   - Your phone must appear correctly under Entra ID → Devices
   - Remove stale or duplicate device objects
   - Ensure the device is not registered under a different tenant

4. Account type and cross-tenant access
   - Guest accounts may not receive passwordless or number-matching challenges

5. Conditional Access policies
   - A CA policy may be forcing a different MFA method or blocking passwordless

6. Other strong authentication methods
   - FIDO2 keys, Windows Hello for Business, TAP, or certificate-based auth may take precedence

If issues persist:
   - Remove Authenticator entries from https://aka.ms/mysecurityinfo
   - Remove the device from Entra ID → Devices
   - Reinstall Microsoft Authenticator
   - Re-register passwordless and MFA

For complete Entra ID setup prerequisites, see: $script:HelpUrl
"@
                    Write-Error $errorMessage -ErrorAction Stop
                }
            }
            else {
                # RemoteNGC exists but params are null - passwordless is available but not set as default
                # This happens when user has passwordless configured but must click "Use an app instead" in browser
                # We need to make an additional API call to explicitly request RemoteNGC credentials
                            
                "[{0}] RemoteNGC available but not default - requesting explicit RemoteNGC credentials" -f $functionName | Write-Verbose
                            
                $beginAuthUrl = "$baseUrl/common/SAS/BeginAuth"
                $beginAuthPayload = @{
                    AuthMethodId = "PhoneAppNotification"
                    Method       = "BeginAuth"
                    ctx          = $FlowToken
                    flowToken    = $FlowToken
                } | ConvertTo-Json -Depth 10
                            
                $beginAuthHeaders = @{
                    "Content-Type"      = "application/json"
                    "canary"            = $CanaryToken
                    "client-request-id" = [guid]::NewGuid().ToString()
                }
                            
                try {
                    "[{0}] Calling BeginAuth to request RemoteNGC credentials" -f $functionName | Write-Verbose
                    $beginAuthResponse = Invoke-RestMethod -Uri $beginAuthUrl -Method POST -ErrorAction Stop `
                        -Headers $beginAuthHeaders -Body $beginAuthPayload -WebSession $Session
                                
                    "[{0}] BeginAuth response: `n{1}" -f $functionName, ($beginAuthResponse | ConvertTo-Json -Depth 10) | ForEach-Object { Format-HPERedactedText -Text $_ } | Write-Verbose
                                
                    # Extract RemoteNGC parameters from BeginAuth response
                    if ($beginAuthResponse.SessionIdentifier -and $beginAuthResponse.Entropy) {
                        $sessionIdentifier = $beginAuthResponse.SessionIdentifier
                        $entropy = $beginAuthResponse.Entropy
                        "[{0}] Successfully obtained RemoteNGC credentials - Entropy: {1}" -f $functionName, $entropy | Write-Verbose
                    }
                    else {
                        Write-Error "BeginAuth response missing SessionIdentifier or Entropy" -ErrorAction Stop
                    }
                }
                catch {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                    }
                    "[{0}] Failed to request RemoteNGC credentials: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    $errorMessage = @"
Microsoft Authenticator passwordless authentication could not be initialized.

DETECTED ISSUE:
Entra ID reported passwordless capability but failed to provide authentication credentials (Entropy missing).
This typically means passwordless authentication is partially configured but not fully functional.

HOW TO FIX:

1. RE-ENROLL MICROSOFT AUTHENTICATOR FOR PASSWORDLESS:
   - Go to: https://aka.ms/mysecurityinfo
   - Sign in with your account
   - REMOVE the existing "Microsoft Authenticator" entry
   - Click "+ Add sign-in method"
   - Select "Microsoft Authenticator"
   - During setup, ensure you select "Phone sign-in" or "Passwordless" option (NOT just MFA)
   - Complete the QR code enrollment
   - Wait 15-30 minutes for changes to propagate

2. VERIFY ENTRA ID AUTHENTICATION METHODS POLICY (Contact your IT administrator):
   - Entra ID → Security → Authentication methods → Microsoft Authenticator
   - Ensure "Passwordless phone sign-in" is ENABLED
   - Verify your user/group is in the "Target" section
   - Check "Authentication mode" is set to allow passwordless

3. CHECK FOR CONFLICTING POLICIES:
   - Conditional Access policies blocking passwordless
   - Legacy per-user MFA enforced (conflicts with modern passwordless)
   - Application-specific authentication requirements

4. VERIFY APPLICATION ASSIGNMENT:
   - Entra ID → Enterprise applications → HPE GreenLake
   - Confirm your account is assigned
   - Verify required app roles are granted

For complete Entra ID setup prerequisites, see: $script:HelpUrl
"@
                    Write-Error $errorMessage -ErrorAction Stop
                }
            }
        }
        else {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
            }
            $errorMessage = @"
Microsoft Authenticator passwordless authentication is not available for this account.

DETECTED ISSUE:
Entra ID reports that RemoteNGC (passwordless) capability is NOT available for this account.
This means passwordless phone sign-in is either not enrolled or not enabled by policy.

HOW TO FIX:

1. ENROLL MICROSOFT AUTHENTICATOR FOR PASSWORDLESS:
   - Install Microsoft Authenticator on your mobile device (if not already installed)
   - Go to: https://aka.ms/mysecurityinfo
   - Sign in with your account
   - Click "+ Add sign-in method"
   - Select "Microsoft Authenticator"
   - IMPORTANT: During setup, select "Phone sign-in" or "Passwordless" option
   - Scan the QR code in the Microsoft Authenticator app
   - Complete the enrollment process
   - Wait 15-30 minutes for changes to propagate

2. VERIFY ENTRA ID POLICIES (Contact your IT administrator):
   
   a) Authentication Methods Policy:
      - Entra ID → Security → Authentication methods → Microsoft Authenticator
      - Verify "Passwordless phone sign-in" is ENABLED at tenant level
      - Verify your user/group is included in the "Target" section
      - Check "Authentication mode" allows passwordless
   
   b) Check Security Defaults:
      - Entra ID → Properties → Manage security defaults
      - If enabled, may need to be disabled for full passwordless support
      - Replace with Conditional Access policies instead
   
   c) Conditional Access Policies:
      - Check if any policies block or restrict passwordless authentication
      - Look for policies requiring specific authentication methods
   
   d) Application Assignment:
      - Entra ID → Enterprise applications → HPE GreenLake (SAML or OIDC app)
      - Verify your account is assigned with appropriate role

3. CHECK FOR CONFLICTING CONFIGURATIONS:
   - Legacy per-user MFA should be disabled (use CA policies instead)
   - No pending forced password resets
   - Account not blocked or in restricted state

4. VERIFY IN MICROSOFT AUTHENTICATOR APP (after enrollment):
   - Open the app on your mobile device
   - Find your work account ($Username)
   - Should show "Phone sign-in enabled"
   - Should NOT only show a 6-digit TOTP code

NOTE: Standard MFA (push approve/deny) is different from passwordless (number matching).
HPE GreenLake requires passwordless phone sign-in with number matching challenges.

For complete Entra ID setup prerequisites, see: $script:HelpUrl
"@
            Write-Error $errorMessage -ErrorAction Stop
        }
    }
    else {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
        }
        Write-Error "Invalid response from Entra ID. Credentials information missing." -ErrorAction Stop
    }

    if (-not $sessionIdentifier) {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
        }
        Write-Error "No authentication session identifier available. Authentication cannot proceed." -ErrorAction Stop
    }
    #EndRegion STEP 2

    #Region STEP 3: Poll DeviceCodeStatus until the user approves the push
    # The real browser "Use an app instead" passwordless flow polls DeviceCodeStatus with the
    # RemoteNGC SessionIdentifier as the DeviceCode (verified against a full HAR capture).
    # AuthorizationState transitions: 0 = pending (keep polling), 2 = approved, 3 = denied/failed.
    "[{0}] Step 3: Polling DeviceCodeStatus for Microsoft Authenticator push approval" -f $functionName | Write-Verbose

    # Show the number-matching prompt (Entropy from GetCredentialType RemoteNgcParams)
    Start-Sleep -Milliseconds 500

    if ($entropy -and $entropy -gt 0) {
        if ($NoProgress) {
            Write-Host "`n  Action required: Open Microsoft Authenticator and enter the number " -NoNewline -ForegroundColor Cyan
            Write-Host $entropy -ForegroundColor Yellow -NoNewline
            Write-Host " to authenticate.`n" -ForegroundColor Cyan
        }
        elseif ($CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                -CurrentActivity "Respond '$entropy' to the Microsoft Authenticator notification" -Id 0
        }
        "[{0}] Number matching active - user must enter: {1}" -f $functionName, $entropy | Write-Verbose
    }
    else {
        if ($NoProgress) {
            Write-Host "`n  Action required: Open Microsoft Authenticator on your phone and approve the sign-in request.`n" -ForegroundColor Cyan
        }
        elseif ($CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                -CurrentActivity "Approve the Microsoft Authenticator push notification on your phone" -Id 0
        }
    }

    # Poll DeviceCodeStatus until the user approves (or timeout)
    "[{0}] Polling DeviceCodeStatus for push approval" -f $functionName | Write-Verbose

    $deviceCodeStatusUrl = "$baseUrl/common/DeviceCodeStatus?code=$([uri]::EscapeDataString($sessionIdentifier))"
    $dcsBody = @{ DeviceCode = $sessionIdentifier } | ConvertTo-Json -Compress
    $dcsTimeout = [datetime]::Now.AddMinutes($TimeoutMinutes)
    $dcsPollCount = 0
    $dcsMaxPolls = 120
    $approved = $false

    do {
        $dcsPollCount++

        $dcsHeaders = @{
            "Accept"            = "application/json"
            "Content-type"      = "application/json; charset=utf-8"
            "canary"            = $CanaryToken
            "client-request-id" = [guid]::NewGuid().ToString()
            "hpgrequestid"      = [guid]::NewGuid().ToString()
        }

        try {
            $dcsResponse = Invoke-RestMethod -Uri $deviceCodeStatusUrl -Method POST -Body $dcsBody `
                -Headers $dcsHeaders -ErrorAction Stop -WebSession $Session

            $authState = $dcsResponse.AuthorizationState
            "[{0}] DeviceCodeStatus poll #{1}: AuthorizationState={2}" -f $functionName, $dcsPollCount, $authState | Write-Verbose

            # AuthorizationState 2 = approved
            if ($authState -eq 2) {
                $approved = $true
                "[{0}] Push notification approved by user" -f $functionName | Write-Verbose
                break
            }

            # AuthorizationState anything other than 0 (pending) or 2 (approved) is terminal (3 = denied/failed)
            if ($authState -ne 0) {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                }
                "[{0}] Push notification denied or failed (AuthorizationState={1})" -f $functionName, $authState | Write-Verbose
                Write-Error "Microsoft Authenticator push notification was denied or failed. The user either declined the request or entered an invalid number." -ErrorAction Stop
            }
            # AuthorizationState 0 = pending — keep polling
        }
        catch {
            if ($_.Exception.Message -notmatch "timeout|timed out") {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                }
                throw
            }
        }

        if ([datetime]::Now -ge $dcsTimeout) {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
            }
            Write-Error @"
Timeout! Microsoft Authenticator push notification was not approved within $TimeoutMinutes minutes.

Please try again and approve the request promptly.
"@ -ErrorAction Stop
        }

        Start-Sleep -Seconds $PollIntervalSeconds
    } until ($approved -or $dcsPollCount -ge $dcsMaxPolls)

    if (-not $approved) {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
        }
        Write-Error "Push notification approval failed or timed out. Please try again." -ErrorAction Stop
    }
    #EndRegion STEP 3

    #Region STEP 4: Complete Authentication and Get SAML Response
    # The approved RemoteNGC challenge is redeemed at /{tenant}/login with type=21 and the
    # SessionIdentifier as the code (verified against a full HAR capture). The response is the
    # KMSI interstitial, which is then POSTed to /kmsi to obtain the final SAMLResponse.
    "[{0}] Step 4: Completing authentication via tenant /login (RemoteNGC type=21)" -f $functionName | Write-Verbose

    # Determine tenant login URL (use tenant UUID from StateToken when available)
    $loginTenantId = "common"
    if ($StateToken -and $StateToken -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
        $loginTenantId = $matches[1]
    }
    $loginUrl = "$baseUrl/$loginTenantId/login"

    $rngcEntropy = if ($entropy) { $entropy } else { "" }
    $loginBody = @(
        "i13=0"
        "code=$([uri]::EscapeDataString($sessionIdentifier))"
        "uaid="
        "login=$([uri]::EscapeDataString($Username))"
        "loginfmt=$([uri]::EscapeDataString($Username))"
        "type=21"
        "LoginOptions=3"
        "ps=4"
        "psRNGCDefaultType=1"
        "psRNGCEntropy=$rngcEntropy"
        "psRNGCSLK=$([uri]::EscapeDataString($sessionIdentifier))"
        "canary=$([uri]::EscapeDataString($CanaryToken))"
        "ctx=$([uri]::EscapeDataString($StateToken))"
        "hpgrequestid=$([guid]::NewGuid().ToString())"
        "flowToken=$([uri]::EscapeDataString($FlowToken))"
        "PPSX="
        "NewUser=1"
        "FoundMSAs="
        "fspost=0"
        "i21=0"
        "CookieDisclosure=0"
        "IsFidoSupported=1"
        "isSignupPost=0"
        "DfpArtifact="
    ) -join '&'

    $loginHeaders = @{
        "Content-Type" = "application/x-www-form-urlencoded"
    }

    try {
        $loginResponse = Invoke-WebRequest -Uri $loginUrl -Method POST -Body $loginBody `
            -Headers $loginHeaders -ErrorAction Stop -WebSession $Session -MaximumRedirection 10

        "[{0}] tenant /login completed (status {1})" -f $functionName, $loginResponse.StatusCode | Write-Verbose

        # Check if we got SAML response directly
        if ($loginResponse.Content -match 'name="SAMLResponse"') {
            "[{0}] SAML response found in login response" -f $functionName | Write-Verbose
                        
            if ($CompletedSteps) { $CompletedSteps.Value++ }
            return $loginResponse
        }
                    
        # Check for KMSI (Keep Me Signed In) page
        $isKmsiPage = $loginResponse.Content -match '"PageID"\s*content="KmsiInterrupt"' -or
        $loginResponse.Content -match '"urlPost"\s*:\s*"/kmsi"'

        if ($isKmsiPage) {
            "[{0}] KMSI (Keep Me Signed In) page detected" -f $functionName | Write-Verbose
                        
            # Extract tokens from JavaScript config or form fields
            $kmsiCtx = ""
            $kmsiFlowToken = ""
            $kmsiCanary = ""
                        
            if ($loginResponse.Content -match '"sFT"\s*:\s*"([^"]+)"') {
                $kmsiFlowToken = $matches[1]
            }
            elseif ($FlowToken) {
                $kmsiFlowToken = $FlowToken
            }
            if ($loginResponse.Content -match '"sCtx"\s*:\s*"([^"]+)"') {
                $kmsiCtx = $matches[1]
            }
            elseif ($StateToken) {
                $kmsiCtx = $StateToken
            }
            if ($loginResponse.Content -match '"canary"\s*:\s*"([^"]+)"') {
                $kmsiCanary = $matches[1]
            }
            elseif ($CanaryToken) {
                $kmsiCanary = $CanaryToken
            }
                        
            $kmsiUrl = "$baseUrl/kmsi"
            $kmsiFormData = @(
                "LoginOptions=1"
                "type=28"
                "ctx=$([uri]::EscapeDataString($kmsiCtx))"
                "flowToken=$([uri]::EscapeDataString($kmsiFlowToken))"
                "canary=$([uri]::EscapeDataString($kmsiCanary))"
            ) -join '&'
                        
            $kmsiResponse = Invoke-WebRequest -Uri $kmsiUrl -Method POST -Body $kmsiFormData `
                -Headers $loginHeaders -ErrorAction Stop -WebSession $Session -MaximumRedirection 10
                        
            "[{0}] KMSI POST completed" -f $functionName | Write-Verbose
                        
            if ($CompletedSteps) { $CompletedSteps.Value++ }
            return $kmsiResponse
        }
                    
        # Return login response if no KMSI
        if ($CompletedSteps) { $CompletedSteps.Value++ }
        return $loginResponse
    }
    catch {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
        }
        "[{0}] Failed to complete authentication flow: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
        Write-Error "Could not complete Entra ID authentication. $($_.Exception.Message)" -ErrorAction Stop
    }
    #EndRegion STEP 4
}

function Invoke-OktaSSOAuthentication {
    <#
            .SYNOPSIS
                Performs Okta passwordless authentication using Okta Verify push notifications or TOTP codes.

            .DESCRIPTION
                This function implements the Okta Identity Engine (IDX) authentication flow:
                1. Introspects authentication state
                2. Identifies user if needed
                3. Selects Okta Verify authenticator and method (push or TOTP)
                4. Handles MFA challenge (push polling or TOTP code entry)
                5. Returns SAML response for completing authentication
                
                Supports both push notifications (with or without number matching) and TOTP codes.
                Automatically prefers push but falls back to TOTP if push is unavailable.

            .PARAMETER StateToken
                The Okta state token from the SAML flow

            .PARAMETER Username
                The user's email address or username

            .PARAMETER Session
                The WebRequestSession to maintain cookies and session state

            .PARAMETER OktaDomain
                The Okta domain (e.g., mycompany.okta.com)

            .PARAMETER NoProgress
                Suppresses progress bar updates (number matching will still be shown)

            .PARAMETER CompletedSteps
                Reference to completed steps counter for progress tracking

            .PARAMETER TotalSteps
                Total number of steps for progress calculation

            .PARAMETER CurrentStep
                Reference to current step counter

            .PARAMETER TimeoutMinutes
                Timeout in minutes for waiting on push notification approval (default: 2)
            
            .PARAMETER PollIntervalSeconds
                Interval in seconds between polling attempts for push notification approval (default: 3)

            .PARAMETER Password
                Optional SecureString password for Okta password-based authentication.
                When provided, selects the Okta password authenticator and submits the password directly
                instead of initiating an Okta Verify push or TOTP challenge.

            .EXAMPLE
                $result = Invoke-OktaSSOAuthentication -StateToken $token -Username "user@example.com" `
                    -Session $session -OktaDomain "mycompany.okta.com"
            #>

    param(
        [Parameter(Mandatory = $true)]
        [string]$StateToken,

        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

        [Parameter(Mandatory = $true)]
        [string]$OktaDomain,

        [Parameter(Mandatory = $false)]
        [switch]$NoProgress,

        [Parameter(Mandatory = $false)]
        [ref]$CompletedSteps,

        [Parameter(Mandatory = $false)]
        [int]$TotalSteps,

        [Parameter(Mandatory = $false)]
        [ref]$CurrentStep,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutMinutes = 2,

        [Parameter(Mandatory = $false)]
        [int]$PollIntervalSeconds = 3,

        [Parameter(Mandatory = $false)]
        [SecureString]$Password
    )

    $functionName = "Invoke-OktaSSOAuthentication".ToUpper()
    $baseUrl = "https://$OktaDomain"
    $script:HelpUrl = "https://github.com/jullienl/HPE-COM-PowerShell-Library/blob/main/README.md"

    # Single progress bar update for the entire MFA process.
    # Label reflects the auth mode: a supplied password means password-based SSO, otherwise passwordless (push/TOTP).
    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
        $oktaAuthModeLabel = if ($Password) { "Okta Password Authentication" } else { "Okta Passwordless Authentication" }
        Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps -CurrentActivity "Step $($CurrentStep.Value)/$TotalSteps - $oktaAuthModeLabel" -Id 0
        $CurrentStep.Value++
    }

    "[{0}] Starting Okta authentication for: {1}" -f $functionName, $baseUrl | Write-Verbose

    #Region STEP 1: Introspect
    "[{0}] Step 1: Introspecting authentication state" -f $functionName | Write-Verbose

    $introspectUrl = "$baseUrl/idp/idx/introspect"
    $payload = @{ stateToken = $StateToken } | ConvertTo-Json -Depth 10
    $headers = @{
        "Content-Type" = "application/json"
        "Accept"       = "application/ion+json; okta-version=1.0.0"
    }

    try {
        $introspectResponse = Invoke-RestMethod -Uri $introspectUrl -Method POST -ErrorAction Stop `
            -Headers $headers -Body $payload -WebSession $Session

        "[{0}] Introspect response received" -f $functionName | Write-Verbose
    }
    catch {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
        }
        "[{0}] Introspect failed: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
        Write-Error "Could not introspect authentication state. $($_.Exception.Message)" -ErrorAction Stop
    }

    # Check for MFA step-up scenario (outdated Okta Verify app)
    $remediationActions = $introspectResponse.remediation.value.name
    if ($remediationActions -contains 'select-authenticator-authenticate') {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
        }
                    
        Write-Error @"
Authentication failed: Outdated Okta Verify app detected.

ROOT CAUSE: Your Okta Verify mobile app is too old to meet current security requirements.

IMMEDIATE SOLUTIONS:
1. UPDATE Okta Verify on your mobile device to the latest version 
2. RE-ENROLL your device if updating doesn't work  

Contact IT support if updating the app doesn't resolve this issue.
"@ -ErrorAction Stop                   

    }
    #EndRegion STEP 1

    #Region STEP 2: Identify (submit username if needed)
    $identifyRemediation = $introspectResponse.remediation.value | Where-Object { $_.name -eq 'identify' }

    if ($identifyRemediation) {
        "[{0}] Step 2: Submitting username" -f $functionName | Write-Verbose
                    
        $identifyUrl = $identifyRemediation.href
        $payload = @{
            identifier  = $Username
            stateHandle = $introspectResponse.stateHandle
        } | ConvertTo-Json -Depth 10

        $headers = @{
            "Content-Type" = "application/json; okta-version=1.0.0"
            "Accept"       = "application/ion+json; okta-version=1.0.0"
        }

        try {
            "[{0}] About to POST to identify endpoint: {1}" -f $functionName, $identifyUrl | Write-Verbose
                        
            $currentResponse = Invoke-RestMethod -Uri $identifyUrl -Method POST -ErrorAction Stop `
                -Headers $headers -Body $payload -WebSession $Session
                        
            "[{0}] Identity submitted successfully" -f $functionName | Write-Verbose
        }
        catch {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }
                        
            "[{0}] Exception Message: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
            "[{0}] HTTP Status Code: {1}" -f $functionName, $_.Exception.Response.StatusCode | Write-Verbose
                        
            # In PowerShell 7, $_.ErrorDetails.Message contains the HTTP response body
            $serverErrorBody = $_.ErrorDetails.Message
            "[{0}] Raw Okta error response: {1}" -f $functionName, $serverErrorBody | Write-Verbose
                        
            # Parse the response to detect specific Okta policy misconfiguration
            $oktaErrorResponse = $null
            if ($serverErrorBody) {
                try { $oktaErrorResponse = $serverErrorBody | ConvertFrom-Json } catch {}
            }
                        
            # Detect password-required error: Okta authentication policy is not configured for passwordless
            $isPasswordRequired = (
                ($oktaErrorResponse.messages.value | Where-Object { $_.message -match 'Expecting a password' }) -or
                ($oktaErrorResponse.currentAuthenticator.value.key -eq 'okta_password')
            )
                        
            if ($isPasswordRequired) {
                $errorMessage = @"
Okta authentication policy misconfiguration detected.

The Okta sign-on policy for the HPE GreenLake application is requiring a password,
but this module only supports passwordless authentication using Okta Verify (push or TOTP).

To fix this, your Okta administrator must configure the passwordless authentication policy:

1. In Okta Admin Console, go to: Applications > HPE GreenLake > Sign On > Authentication Policy
2. Edit the policy rule and set 'User must authenticate with' to 'Any 1 factor type' (not Password)
3. Ensure Okta Verify is enrolled and that the Possession factor is allowed without password

For complete Okta passwordless setup instructions, see: $script:HelpUrl
"@
            }
            else {
                $errorDetailsDisplay = if ($oktaErrorResponse) {
                    $oktaErrorResponse | ConvertTo-Json -Depth 3
                }
                elseif ($serverErrorBody) {
                    $serverErrorBody
                }
                else {
                    "(Unable to extract error details from response)"
                }
                            
                $errorMessage = @"
User authentication failed.

This error can occur for multiple reasons:

1. User account does not exist in Okta
2. User account is disabled or locked
3. User is not assigned to the HPE GreenLake application in Okta
   - Contact your Okta administrator to verify application access
   - Ensure you have the required app role assignments

4. Okta Identity Engine (OIE) API compatibility issue
   - The Okta platform may have been upgraded from Classic to OIE
   - Different API structure or authentication flow required

Server Error Details:
$errorDetailsDisplay

For complete Okta setup prerequisites, see: $script:HelpUrl
"@
            }
                        
            Write-Error $errorMessage -ErrorAction Stop
        }
    }
    else {
        $currentResponse = $introspectResponse
    }
    #EndRegion STEP 2

    #Region STEP 3: Select Authenticator and Method
    "[{0}] Step 3: Selecting authenticator" -f $functionName | Write-Verbose

    $stateHandle = $currentResponse.stateHandle
    $selectAuthRemediation = $currentResponse.remediation.value | Where-Object { $_.name -eq 'select-authenticator-authenticate' }

    if (-not $selectAuthRemediation) {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
        }
        Write-Error "Authenticator selection not available. For Okta setup prerequisites, see: $($script:HelpUrl)" -ErrorAction Stop
    }

    $challengeHref = $selectAuthRemediation.href
    $allAuthOptions = ($selectAuthRemediation.value | Where-Object { $_.name -eq 'authenticator' }).options
    $isPasswordAuthenticator = $false
    $passwordlessWarningSent = $false
    $passwordlessPreferred = $false

    # When a password is supplied, an Okta passwordless policy and a password+MFA policy are
    # INDISTINGUISHABLE here — both advertise a Password authenticator AND Okta Verify (push/TOTP).
    # The only reliable way to tell them apart is at runtime: a passwordless policy is satisfied by
    # Okta Verify alone, whereas a password+MFA policy still demands the password afterwards.
    #
    # Strategy when a password is supplied:
    # - If Okta Verify offers PUSH, try Okta Verify push FIRST (the passwordless route). If push
    #   alone satisfies Okta (passwordless policy, e.g. FastPass), the password is never used and a
    #   "password not required" warning is emitted after success (e.g. LeeG). If Okta then ALSO
    #   requires the password (password+MFA policy), the existing STEP 7 push fallback submits it
    #   silently — no warning (e.g. Marc).
    # - Otherwise (Okta Verify offers only TOTP, or no Okta Verify) submit the Password FIRST, with
    #   automatic step-up MFA in STEP 5 if required. This keeps password+TOTP (e.g. Leon) and
    #   password-only (e.g. AlbE) accounts on their proven password-first flow.
    if ($Password) {
        $passwordAuth = $allAuthOptions | Where-Object {
            $_.label -match 'Password' -or
            ($_.value.form.value | Where-Object { $_.name -eq 'key' }).value -eq 'okta_password'
        }
        $OktaVerifyAuth = $allAuthOptions | Where-Object { $_.label -like '*Okta*Verify*' }
        $oktaVerifyMethodOptions = ($OktaVerifyAuth.value.form.value | Where-Object { $_.name -eq 'methodType' }).options

        if ($OktaVerifyAuth -and ($oktaVerifyMethodOptions.value -contains 'push')) {
            # Passwordless-preferred: Okta Verify push first; password held in reserve.
            $isPasswordAuthenticator = $false
            $passwordlessPreferred = $true
            $authenticatorId = ($OktaVerifyAuth.value.form.value | Where-Object { $_.name -eq 'id' }).value
            $methodType = 'push'
            "[{0}] Okta Verify push selected first (passwordless route); password held in reserve for password+MFA policies" -f $functionName | Write-Verbose
        }
        elseif ($passwordAuth) {
            $isPasswordAuthenticator = $true
            $authenticatorId = ($passwordAuth.value.form.value | Where-Object { $_.name -eq "id" }).value
            $methodType = $null
            "[{0}] Password authenticator selected (id: {1}) — password-first, automatic MFA step-up if required" -f $functionName, $authenticatorId | Write-Verbose
        }
        # else: neither a password authenticator nor Okta Verify push offered — genuinely
        #       passwordless (e.g. TOTP-only); fall through to the Okta Verify path below.
    }

    if (-not $isPasswordAuthenticator -and -not $passwordlessPreferred) {
        if ($Password -and -not $passwordlessWarningSent) {
            Write-Warning @"
Your Okta account uses passwordless authentication. The provided password will not be used — attempting SSO (push/TOTP) authentication instead.
To avoid this warning, use -PasswordlessSSOEmail instead of -Credential.
"@
        }
        $OktaVerify = $allAuthOptions | Where-Object { $_.label -like '*Okta*Verify*' }

        if (-not $OktaVerify) {
            # Step 18: Check if a password authenticator is available — prompt interactively if $Password not provided
            $passwordAuthOption = $allAuthOptions | Where-Object {
                $_.label -match 'Password' -or
                ($_.value.form.value | Where-Object { $_.name -eq 'key' }).value -eq 'okta_password'
            }
            if ($passwordAuthOption -and -not $Password) {
                # -PasswordlessSSOEmail must never prompt interactively — fail with an actionable error.
                "[{0}] Okta account requires a password but -PasswordlessSSOEmail was used — returning error." -f $functionName | Write-Verbose
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                }
                # The IdP confirmed this account is password-based — record the rejection as password-based for telemetry.
                $Global:HPESSOPasswordSubmitted = $true
                Write-Error @"
Authentication failed: '$Username' is configured for password-based authentication in Okta, not passwordless.

Your Identity Provider (Okta) requires a password for this account.
Use -Credential instead:

   `$cred = Get-Credential -UserName '$Username'
   Connect-HPEGL -Credential `$cred
"@ -ErrorAction Stop
            }
            else {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                }
                $errorMessage = @"
Okta Verify passwordless authentication is not enabled for this account.

This error can occur for multiple reasons:

1. Okta Verify is not enrolled with push notifications or TOTP codes
   - Install Okta Verify on your mobile device
   - Enroll Okta Verify in your Okta account settings
   - Ensure either push notifications or TOTP (Time-based One-Time Password) is enabled
   - Test the enrollment by signing in through a web browser first

2. User is not assigned to the HPE GreenLake application in Okta
   - Contact your Okta administrator to verify application access
   - Ensure you have the required app role assignments

For complete Okta setup prerequisites, see: $script:HelpUrl
"@
                Write-Error $errorMessage -ErrorAction Stop
            }
        }

        if (-not $isPasswordAuthenticator) {
            $authenticatorId = ($OktaVerify.value.form.value | Where-Object { $_.name -eq "id" }).value
            $methodOptions = ($OktaVerify.value.form.value | Where-Object { $_.name -eq "methodType" }).options

            if (-not $authenticatorId -or -not $methodOptions) {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                }
                Write-Error "Invalid Okta Verify configuration. For Okta setup prerequisites, see: $($script:HelpUrl)" -ErrorAction Stop
            }

            # Select method: prefer push, fallback to TOTP
            $methodType = if ($methodOptions.value -contains "push") {
                "[{0}] Selected method: push" -f $functionName | Write-Verbose
                "push"
            }
            elseif ($methodOptions.value -contains "totp") {
                "[{0}] Selected method: totp (push not available)" -f $functionName | Write-Verbose
                "totp"
            }
            else {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                }
                Write-Error "Neither push nor TOTP authentication available. For Okta setup prerequisites, see: $($script:HelpUrl)" -ErrorAction Stop
            }
        } 
    } 
    #EndRegion STEP 3

    #Region STEP 4: Trigger Challenge
    $challengeLabel = if ($isPasswordAuthenticator) { "password" } else { $methodType }
    "[{0}] Step 4: Initiating {1} challenge" -f $functionName, $challengeLabel | Write-Verbose

    $payload = if ($isPasswordAuthenticator) {
        @{
            stateHandle   = $stateHandle
            authenticator = @{ id = $authenticatorId }
        } | ConvertTo-Json -Depth 10
    }
    else {
        @{
            stateHandle   = $stateHandle
            authenticator = @{
                id         = $authenticatorId
                methodType = $methodType
            }
        } | ConvertTo-Json -Depth 10
    }

    $headers = @{
        "Content-Type" = "application/json; okta-version=1.0.0"
        "Accept"       = "application/ion+json; okta-version=1.0.0"
    }

    try {
        $challengeResponse = Invoke-RestMethod -Uri $challengeHref -Method POST -ErrorAction Stop -Headers $headers -Body $payload -WebSession $Session

        "[{0}] {1} challenge initiated successfully" -f $functionName, $challengeLabel.ToUpper() | Write-Verbose
    }
    catch {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
        }
        "[{0}] Failed to initiate {1} challenge: {2}" -f $functionName, $challengeLabel, $_.Exception.Message | Write-Verbose
        Write-Error "Could not initiate Okta Verify $($challengeLabel) challenge. $($_.Exception.Message)" -ErrorAction Stop
    }

    $stateHandle = $challengeResponse.stateHandle
    #EndRegion STEP 4

    #Region STEP 5: Handle Password Authentication
    if ($isPasswordAuthenticator) {
        "[{0}] Step 5: Handling password authentication" -f $functionName | Write-Verbose

        $answerHref = ($challengeResponse.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' }).href

        if (-not $answerHref) {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }
            Write-Error "No challenge-authenticator href found in password challenge response" -ErrorAction Stop
        }

        # Decrypt password SecureString to plaintext — cleared immediately after use
        $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
        try {
            $passwordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr)
        }
        finally {
            [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr)
        }

        $payload = @{
            stateHandle = $stateHandle
            credentials = @{ passcode = $passwordPlainText }
        } | ConvertTo-Json -Depth 10
        $passwordPlainText = $null

        $headers = @{
            "Content-Type" = "application/json; okta-version=1.0.0"
            "Accept"       = "application/ion+json; okta-version=1.0.0"
        }

        try {
            # Password is about to be submitted to Okta — flag this connection as genuinely
            # password-based for telemetry (set before the POST so a rejected/bad password still counts).
            $Global:HPESSOPasswordSubmitted = $true
            $passwordResponse = Invoke-RestMethod -Uri $answerHref -Method POST -ErrorAction Stop `
                -Headers $headers -Body $payload -WebSession $Session

            "[{0}] Password submitted successfully" -f $functionName | Write-Verbose
        }
        catch {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }
            "[{0}] Failed to submit password: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
            Write-Error "Authentication failed: Okta rejected the credentials for '$Username'. Verify username and password. Error: $($_.Exception.Message)" -ErrorAction Stop
        }

        $successRedirectUrl = $passwordResponse.success.href
        if (-not $successRedirectUrl) {
            $successRedirectUrl = $passwordResponse.successWithInteractionCode.href
        }

        # --- Step-up MFA detection ---
        # If Okta requires a second factor after password, the IDX response contains
        # select-authenticator-authenticate instead of a success redirect.
        $stepUpRemediation = $passwordResponse.remediation.value | Where-Object { $_.name -eq 'select-authenticator-authenticate' }

        if ($stepUpRemediation -and -not $successRedirectUrl) {
            "[{0}] Step-up MFA required after password — selecting Okta Verify" -f $functionName | Write-Verbose

            $stateHandle = $passwordResponse.stateHandle
            $challengeHref = $stepUpRemediation.href
            $allStepUpOpts = ($stepUpRemediation.value | Where-Object { $_.name -eq 'authenticator' }).options
            $OktaVerify = $allStepUpOpts | Where-Object { $_.label -like '*Okta*Verify*' }

            if (-not $OktaVerify) {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                }
                Write-Error "Step-up MFA required but Okta Verify is not available. For Okta setup prerequisites, see: $($script:HelpUrl)" -ErrorAction Stop
            }

            $authenticatorId = ($OktaVerify.value.form.value | Where-Object { $_.name -eq "id" }).value
            $methodOptions = ($OktaVerify.value.form.value | Where-Object { $_.name -eq "methodType" }).options
            $methodType = if ($methodOptions.value -contains "push") { "push" }
            elseif ($methodOptions.value -contains "totp") { "totp" }
            else {
                Write-Error "Neither push nor TOTP available for step-up MFA. For Okta setup prerequisites, see: $($script:HelpUrl)" -ErrorAction Stop
            }

            "[{0}] Step-up: selected method '{1}', re-posting challenge" -f $functionName, $methodType | Write-Verbose

            $stepUpPayload = @{
                stateHandle   = $stateHandle
                authenticator = @{ id = $authenticatorId; methodType = $methodType }
            } | ConvertTo-Json -Depth 10

            $stepUpHeaders = @{
                "Content-Type" = "application/json; okta-version=1.0.0"
                "Accept"       = "application/ion+json; okta-version=1.0.0"
            }

            try {
                $challengeResponse = Invoke-RestMethod -Uri $challengeHref -Method POST `
                    -ErrorAction Stop -Headers $stepUpHeaders -Body $stepUpPayload -WebSession $Session

                "[{0}] Step-up {1} challenge initiated" -f $functionName, $methodType.ToUpper() | Write-Verbose
            }
            catch {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                }
                Write-Error "Could not initiate step-up Okta Verify $($methodType) challenge. $($_.Exception.Message)" -ErrorAction Stop
            }

            $stateHandle = $challengeResponse.stateHandle
            $isPasswordAuthenticator = $false
            $mfaRequired = $true
            # Fall through to STEP 6 (TOTP) or STEP 7 (push) below
        }
        elseif (-not $successRedirectUrl) {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }
            Write-Error "No success redirect URL found after password authentication" -ErrorAction Stop
        }
        else {
            "[{0}] Password authentication completed successfully" -f $functionName | Write-Verbose
            "[{0}] Following success redirect to retrieve SAML response" -f $functionName | Write-Verbose

            try {
                $samlResponse = Invoke-WebRequest -Uri $successRedirectUrl -Method GET `
                    -WebSession $Session -UseBasicParsing -MaximumRedirection 10 -ErrorAction Stop

                "[{0}] SAML response retrieved successfully" -f $functionName | Write-Verbose

                if ($CompletedSteps) { $CompletedSteps.Value++ }
                return $samlResponse
            }
            catch {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                }
                Write-Error "Could not retrieve SAML response after password authentication. $($_.Exception.Message)" -ErrorAction Stop
            }
        }
    }
    #EndRegion STEP 5

    #Region STEP 6: Handle TOTP Input
    if ($methodType -eq "totp") {
        "[{0}] Step 6: Handling TOTP authentication" -f $functionName | Write-Verbose

        $totpCode = Read-Host -Prompt "Enter your Okta Verify TOTP code for $($Username)"

        if ([string]::IsNullOrWhiteSpace($totpCode)) {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }
            Write-Error "TOTP code is required" -ErrorAction Stop
        }

        $answerHref = ($challengeResponse.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' }).href

        if (-not $answerHref) {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }
            Write-Error "No answerHref found in TOTP challenge response" -ErrorAction Stop
        }

        $payload = @{
            stateHandle = $stateHandle
            credentials = @{ totp = $totpCode }
        } | ConvertTo-Json -Depth 10

        $headers = @{
            "Content-Type" = "application/json; okta-version=1.0.0"
            "Accept"       = "application/ion+json; okta-version=1.0.0"
        }

        try {
            $totpResponse = Invoke-RestMethod -Uri $answerHref -Method POST -ErrorAction Stop `
                -Headers $headers -Body $payload -WebSession $Session

            "[{0}] TOTP code submitted successfully" -f $functionName | Write-Verbose
        }
        catch {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }

            $errorMessage = "Invalid TOTP code. Please verify the code and try again"
                        
            if ($_.Exception.Response) {
                try {
                    $errorStream = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($errorStream)
                    $errorBody = $reader.ReadToEnd()
                    $reader.Close()
                    $errorJson = $errorBody | ConvertFrom-Json
                                
                    if ($errorJson.errorSummary) {
                        $errorMessage = $errorJson.errorSummary
                    }
                }
                catch { 
                    # Intentionally ignore - JSON parsing may fail for non-JSON error responses
                }
            }

            "[{0}] Failed to submit TOTP code: {1}" -f $functionName, $errorMessage | Write-Verbose
            throw "Authentication failed: The verification code was rejected by Okta. Verify the current code in your authenticator app and try again."
        }

        # Check for multi-factor authentication (TOTP + Password)
        $additionalAuthRequired = $totpResponse.remediation.value | Where-Object { 
            $_.name -eq 'challenge-authenticator' -and $_.relatesTo -contains '$.currentAuthenticatorEnrollment'
        }

        if ($additionalAuthRequired) {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }
            Write-Error @"
Multi-factor authentication (TOTP + additional factor) is not supported.

Please configure Okta to use TOTP alone.

For setup prerequisites, see: $script:HelpUrl
"@ -ErrorAction Stop
        }

        # Extract success redirect URL
        $successRedirectUrl = $totpResponse.success.href
        if (-not $successRedirectUrl) {
            $successRedirectUrl = $totpResponse.successWithInteractionCode.href
        }

        if (-not $successRedirectUrl) {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }
            Write-Error "No success redirect URL found after TOTP verification" -ErrorAction Stop
        }

        "[{0}] TOTP verification completed successfully" -f $functionName | Write-Verbose
        "[{0}] Following success redirect to retrieve SAML response" -f $functionName | Write-Verbose

        try {
            $samlResponse = Invoke-WebRequest -Uri $successRedirectUrl -Method GET -WebSession $Session -UseBasicParsing -MaximumRedirection 10 -ErrorAction Stop

            "[{0}] SAML response retrieved successfully" -f $functionName | Write-Verbose

            if ($CompletedSteps) { $CompletedSteps.Value++ }
            return $samlResponse
        }
        catch {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }
            Write-Error "Could not retrieve SAML response. $($_.Exception.Message)" -ErrorAction Stop
        }
    }
    #EndRegion STEP 6

    #Region STEP 7: Poll for Push Approval
    if ($methodType -eq "push") {
        "[{0}] Step 7: Polling for push approval" -f $functionName | Write-Verbose

        $pollHref = ($challengeResponse.remediation.value | Where-Object { $_.name -eq 'challenge-poll' }).href

        if (-not $pollHref) {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }
            Write-Error "No pollHref found for push authentication" -ErrorAction Stop
        }

        $correctAnswer = $challengeResponse.currentAuthenticator.value.contextualData.correctAnswer

        Start-Sleep -Milliseconds 500

        if ($correctAnswer) {
            if ($NoProgress) {
                Write-Host "`n  Action required: Open Okta Verify and select the number " -NoNewline -ForegroundColor Cyan
                Write-Host $correctAnswer -ForegroundColor Yellow -NoNewline
                Write-Host " to authenticate.`n" -ForegroundColor Cyan
            }
            else {
                Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                    -CurrentActivity "Respond '$correctAnswer' to the Okta Verify notification" -Id 0
            }
            "[{0}] Number challenge active - user must select: {1}" -f $functionName, $correctAnswer | Write-Verbose
        }
        else {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                    -CurrentActivity "Approve the Okta Verify push notification" -Id 0
            }
        }

        $timeout = [datetime]::Now.AddMinutes($TimeoutMinutes)
        $payload = @{ stateHandle = $stateHandle } | ConvertTo-Json
        $headers = @{
            "Content-Type" = "application/json; okta-version=1.0.0"
            "Accept"       = "application/ion+json; okta-version=1.0.0"
        }

        do {
            try {
                $pollResponse = Invoke-RestMethod -Uri $pollHref -Method POST -Body $payload `
                    -Headers $headers -ErrorAction Stop -WebSession $Session
            }
            catch {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                }
                Write-Error "Unable to poll Okta Verify push status. $($_.Exception.Message)" -ErrorAction Stop
            }

            # Check for timeout
            if ([datetime]::Now -ge $timeout) {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                }
                Write-Error @"
Timeout! Okta Verify push notification was not approved within $TimeoutMinutes minutes.

Please try again and approve the request promptly.
"@ -ErrorAction Stop
            }

            # Check for success
            if ($pollResponse.success.name -eq "success-redirect" -or $pollResponse.successWithInteractionCode) {
                break
            }

            # Check for multi-factor authentication requirement
            if ($pollResponse.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' -and $_.relatesTo -contains '$.currentAuthenticatorEnrollment' }) {
                break
            }

            # Check for error
            if ($pollResponse.messages -and $pollResponse.messages.value -and $pollResponse.messages.value.Count -gt 0) {
                if ($pollResponse.messages.value[0].class -eq "ERROR") {
                    break
                }
            }

            Start-Sleep -Seconds $PollIntervalSeconds

        } while ($true)

        # Check for Push + Password scenario
        if ($pollResponse.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' -and $_.relatesTo -contains '$.currentAuthenticatorEnrollment' }) {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }

            # If no password was provided, this is a password-based account used with -PasswordlessSSOEmail.
            # Return an actionable error directing the user to -Credential.
            if (-not $Password) {
                # The IdP confirmed this account is password-based — record the rejection as password-based for telemetry.
                $Global:HPESSOPasswordSubmitted = $true
                Write-Error @"
Authentication failed: '$Username' is configured for password-based authentication in Okta, not passwordless.

Your Identity Provider (Okta) requires a password for this account.
Use -Credential instead:

   `$cred = Get-Credential -UserName '$Username'
   Connect-HPEGL -Credential `$cred
"@ -ErrorAction Stop
            }
            else {
                # Push requires an additional factor and a password is available.
                # Fall back to password authentication silently.
                "[{0}] Push requires additional factor — falling back to password authentication" -f $functionName | Write-Verbose

                # The password is being used (password+MFA policy) — suppress the passwordless warning.
                $passwordlessPreferred = $false

                $isPasswordAuthenticator = $true
                $authenticatorId = ($passwordAuth.value.form.value | Where-Object { $_.name -eq "id" }).value

                # Re-challenge with password authenticator
                $pwFallbackPayload = @{
                    stateHandle   = $stateHandle
                    authenticator = @{ id = $authenticatorId }
                } | ConvertTo-Json -Depth 10
                $pwFallbackHeaders = @{
                    "Content-Type" = "application/json; okta-version=1.0.0"
                    "Accept"       = "application/ion+json; okta-version=1.0.0"
                }
                try {
                    $challengeResponse = Invoke-RestMethod -Uri $challengeHref -Method POST `
                        -ErrorAction Stop -Headers $pwFallbackHeaders -Body $pwFallbackPayload -WebSession $Session
                    $stateHandle = $challengeResponse.stateHandle
                    "[{0}] Password challenge initiated for fallback" -f $functionName | Write-Verbose
                }
                catch {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                    }
                    Write-Error "Could not initiate password challenge after push fallback. $($_.Exception.Message)" -ErrorAction Stop
                }

                # Submit password
                $answerHref = ($challengeResponse.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' }).href
                $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password)
                try { $passwordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
                finally { [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
                $pwPayload = @{ stateHandle = $stateHandle; credentials = @{ passcode = $passwordPlainText } } | ConvertTo-Json -Depth 10
                $passwordPlainText = $null
                try {
                    # Password is about to be submitted to Okta (push fallback) — flag this connection as
                    # genuinely password-based for telemetry (set before the POST so a rejected password still counts).
                    $Global:HPESSOPasswordSubmitted = $true
                    $passwordResponse = Invoke-RestMethod -Uri $answerHref -Method POST `
                        -ErrorAction Stop -Headers $pwFallbackHeaders -Body $pwPayload -WebSession $Session
                    "[{0}] Password submitted successfully (push fallback)" -f $functionName | Write-Verbose
                }
                catch {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                    }
                    Write-Error "Authentication failed: Okta rejected the credentials for '$Username'. Verify username and password. Error: $($_.Exception.Message)" -ErrorAction Stop
                }

                # Handle step-up MFA or success after password fallback
                $successRedirectUrl = $passwordResponse.success.href
                if (-not $successRedirectUrl) { $successRedirectUrl = $passwordResponse.successWithInteractionCode.href }
                $stepUpRemediation = $passwordResponse.remediation.value | Where-Object { $_.name -eq 'select-authenticator-authenticate' }

                if ($stepUpRemediation -and -not $successRedirectUrl) {
                    # Step-up MFA required — delegate to existing step-up logic by re-entering STEP 5 flow
                    # Reuse the existing $passwordResponse step-up block by setting variables and falling through
                    $isPasswordAuthenticator = $false
                    $stateHandle = $passwordResponse.stateHandle
                    $challengeHref = $stepUpRemediation.href
                    $allStepUpOpts = ($stepUpRemediation.value | Where-Object { $_.name -eq 'authenticator' }).options
                    $OktaVerify = $allStepUpOpts | Where-Object { $_.label -like '*Okta*Verify*' }
                    if (-not $OktaVerify) {
                        Write-Error "Step-up MFA required but Okta Verify is not available after password fallback." -ErrorAction Stop
                    }
                    $authenticatorId = ($OktaVerify.value.form.value | Where-Object { $_.name -eq 'id' }).value
                    $methodOptions = ($OktaVerify.value.form.value | Where-Object { $_.name -eq 'methodType' }).options
                    $methodType = if ($methodOptions.value -contains 'push') { 'push' } elseif ($methodOptions.value -contains 'totp') { 'totp' } else { $null }
                    $stepPayload = @{ stateHandle = $stateHandle; authenticator = @{ id = $authenticatorId; methodType = $methodType } } | ConvertTo-Json -Depth 10
                    $challengeResponse = Invoke-RestMethod -Uri $challengeHref -Method POST -ErrorAction Stop -Headers $pwFallbackHeaders -Body $stepPayload -WebSession $Session
                    $stateHandle = $challengeResponse.stateHandle
                    $mfaRequired = $true
                    # Fall through to STEP 6 (TOTP) or STEP 7 (push) below
                }
                elseif ($successRedirectUrl) {
                    try {
                        $samlResponse = Invoke-WebRequest -Uri $successRedirectUrl -Method GET -WebSession $Session -UseBasicParsing -MaximumRedirection 10 -ErrorAction Stop
                        if ($CompletedSteps) { $CompletedSteps.Value++ }
                        return $samlResponse
                    }
                    catch {
                        Write-Error "Could not retrieve SAML response after password fallback. $($_.Exception.Message)" -ErrorAction Stop
                    }
                }
                else {
                    Write-Error "No success redirect URL found after password fallback authentication" -ErrorAction Stop
                }
            }
        }

        # Check for push denial - with proper null checking
        if ($pollResponse.messages -and $pollResponse.messages.value -and $pollResponse.messages.value.Count -gt 0 -and $pollResponse.messages.value[0].class -eq "ERROR") {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }
            $errorMsg = if ($pollResponse.messages.value[0].message) { $pollResponse.messages.value[0].message } else { "Unknown error" }
            "[{0}] Push notification denied: {1}" -f $functionName, $errorMsg | Write-Verbose
            Write-Error "Okta Verify push notification was denied. The user either rejected the notification or selected the wrong number on the Okta Verify prompt. Please try again and approve the request on your device." -ErrorAction Stop
        }

        # Check for success and extract redirect URL
        if ($pollResponse.success.name -eq "success-redirect" -or $pollResponse.successWithInteractionCode) {
            # Extract success redirect URL
            $successRedirectUrl = $pollResponse.success.href
            if (-not $successRedirectUrl) {
                $successRedirectUrl = $pollResponse.successWithInteractionCode.href
            }

            if (-not $successRedirectUrl) {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                }
                Write-Error "No success redirect URL found after push approval" -ErrorAction Stop
            }

            "[{0}] Push notification approved successfully" -f $functionName | Write-Verbose
            "[{0}] Following success redirect to retrieve SAML response" -f $functionName | Write-Verbose

            # Okta Verify push alone satisfied authentication and the supplied password was never
            # used — this is a passwordless policy. Warn the user (consistent with Entra ID / PingID).
            if ($passwordlessPreferred) {
                "[{0}] Okta Verify push alone satisfied authentication — supplied password was not used (passwordless policy)" -f $functionName | Write-Verbose
                Write-Warning @"
Your Okta account uses passwordless authentication. The provided password will not be used — attempting SSO (push/TOTP) authentication instead.
To avoid this warning, use -PasswordlessSSOEmail instead of -Credential.
"@
            }

            try {
                $samlResponse = Invoke-WebRequest -Uri $successRedirectUrl -Method GET `
                    -WebSession $Session -UseBasicParsing -MaximumRedirection 10 -ErrorAction Stop

                "[{0}] SAML response retrieved successfully" -f $functionName | Write-Verbose

                if ($CompletedSteps) { $CompletedSteps.Value++ }
                return $samlResponse
            }
            catch {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                }
                Write-Error "Could not retrieve SAML response. $($_.Exception.Message)" -ErrorAction Stop
            }
        }
        else {
            # If we get here, something unexpected happened
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
            }
            Write-Error "Unexpected response from push polling. Please try again." -ErrorAction Stop
        }
    }
    #EndRegion STEP 7
}

function Invoke-PingIDSSOAuthentication {
    <#
            .SYNOPSIS
                Performs PingOne/PingID SAML authentication using PingID mobile app push notifications or OTP codes.

            .DESCRIPTION
                This function implements the PingOne SAML + PingID authentication flow:
                1. Follows SAML redirect to extract flowId from PingOne
                2. Submits username to PingOne flows API
                3. Initiates PingID authentication via authenticator.pingone.com
                4. Waits for user to approve push notification on mobile device
                5. Handles JWT callback with ppm_request and ppm_response tokens
                6. Resumes SAML flow to retrieve final SAML response
                
                Authentication Methods:
                - Push Notification (Primary): Sends push to mobile device with optional number matching
                - OTP Fallback (Automatic): Only available if push is unavailable or fails
                
                IMPORTANT: PingID architecture ALWAYS sends a push notification after WebAuthn submission.
                The push notification MUST be approved - denying or ignoring it breaks the authentication session.
                There is no way to skip or cancel the push notification.

            .PARAMETER SAMLRedirectUrl
                The full SAML redirect URL from the IdP initiation (contains flowId parameter)

            .PARAMETER Username
                The user's email address or username

            .PARAMETER Session
                The WebRequestSession to maintain cookies and session state

            .PARAMETER EnvironmentId
                The PingOne environment ID (e.g., a4ff1a35-682b-469f-9acf-373ee0508d31)

            .PARAMETER NoProgress
                Suppresses progress bar updates (number matching will still be shown)

            .PARAMETER CompletedSteps
                Reference to completed steps counter for progress tracking

            .PARAMETER TotalSteps
                Total number of steps for progress calculation

            .PARAMETER CurrentStep
                Reference to current step counter

            .PARAMETER TimeoutMinutes
                Maximum time to wait for push approval (default: 2 minutes)

            .PARAMETER PollIntervalSeconds
                Interval between status polls (default: 3 seconds)

            .PARAMETER Password
                Optional SecureString password for PingID password-based authentication.
                When provided, submits the password to the PingOne password.verify endpoint instead of
                waiting for a PingID push notification or OTP challenge.

            .EXAMPLE
                $result = Invoke-PingIDSSOAuthentication -SAMLRedirectUrl $redirectUrl -Username "user@example.com" `
                    -Session $session -EnvironmentId "a4ff1a35-682b-469f-9acf-373ee0508d31"
                
                Authenticates using push notification. User must approve the push on their mobile device.

            .EXAMPLE
                $result = Invoke-PingIDSSOAuthentication -SAMLRedirectUrl $redirectUrl -Username "user@example.com" `
                    -Session $session -EnvironmentId "a4ff1a35-682b-469f-9acf-373ee0508d31" -TimeoutMinutes 5
                
                Authenticates using push notification with extended timeout of 5 minutes.
            #>

    param(
        [Parameter(Mandatory = $true)]
        [string]$SAMLRedirectUrl,

        [Parameter(Mandatory = $true)]
        [string]$Username,

        [Parameter(Mandatory = $true)]
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

        [Parameter(Mandatory = $true)]
        [string]$EnvironmentId,

        [Parameter(Mandatory = $false)]
        [switch]$NoProgress,

        [Parameter(Mandatory = $false)]
        [ref]$CompletedSteps,

        [Parameter(Mandatory = $false)]
        [int]$TotalSteps,

        [Parameter(Mandatory = $false)]
        [ref]$CurrentStep,

        [Parameter(Mandatory = $false)]
        [int]$TimeoutMinutes = 2,

        [Parameter(Mandatory = $false)]
        [int]$PollIntervalSeconds = 3,

        [Parameter(Mandatory = $false)]
        [SecureString]$Password,

        # OIDC federation: resume the PingOne flow through the OpenID Connect endpoint ('/as/resume'), which redirects back
        # to HPE GreenLake with an authorization code, instead of the SAML endpoint ('/saml20/resume').
        [Parameter(Mandatory = $false)]
        [switch]$OidcFlow
    )

    $functionName = "Invoke-PingIDSSOAuthentication".ToUpper()
    $skipToSamlResume = $false
                
    # Extract PingOne base URLs directly from SAMLRedirectUrl instead of reconstructing
    # This automatically supports ALL regions including .com, .eu, .asia, .ca, .com.au, .sg, and future regions
    $authBaseUrl = $null
    $authenticatorBaseUrl = $null
    $detectedRegion = "unknown"
                
    # Extract base URL from SAMLRedirectUrl (works with any subdomain: auth., apps., authenticator.)
    # Match pattern: https://(any).pingone.(any TLD)/
    if ($SAMLRedirectUrl -match 'https://([^/]+\.)?pingone\.([^/]+)') {
        # Extract the full domain (e.g., "eu", "com.au", "sg")
        $detectedRegion = $Matches[2]
        $authBaseUrl = "https://auth.pingone.$detectedRegion"
        "[{0}] Extracted region '{1}' from URL: {2}" -f $functionName, $detectedRegion, $SAMLRedirectUrl | Write-Verbose
        "[{0}] Constructed auth base URL: {1}" -f $functionName, $authBaseUrl | Write-Verbose
    }
                
    # Construct authenticator URL
    if ($authBaseUrl) {
        $authenticatorBaseUrl = $authBaseUrl -replace '^https://auth\.', 'https://authenticator.'
        "[{0}] Constructed authenticator base URL: {1}" -f $functionName, $authenticatorBaseUrl | Write-Verbose
    }
                
    # Fallback to default if extraction failed
    if (-not $authBaseUrl) {
        "[{0}] WARNING: Could not extract base URLs from SAML redirect, falling back to .com default" -f $functionName | Write-Verbose
        $authBaseUrl = "https://auth.pingone.com"
        $authenticatorBaseUrl = "https://authenticator.pingone.com"
        $detectedRegion = "com (fallback)"
    }
                
    "[{0}] Using PingOne region: {1}" -f $functionName, $detectedRegion | Write-Verbose
    $script:HelpUrl = "https://github.com/jullienl/HPE-COM-PowerShell-Library/blob/main/README.md"

    # Single progress bar update for the entire MFA process
    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
        $currentStepValue = $CurrentStep.Value
        $pingAuthLabel = if ($Password) { "PingID Password Authentication" } else { "PingID Passwordless Authentication" }
        Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps -CurrentActivity "Step $currentStepValue/$TotalSteps - $pingAuthLabel" -Id 0
        $CurrentStep.Value++
    }

    "[{0}] Starting PingOne/PingID authentication for environment: {1}" -f $functionName, $EnvironmentId | Write-Verbose

    #Region STEP 1: Follow SAML redirect and extract flowId
    "[{0}] Step 1: Following {1} redirect to extract flowId" -f $functionName, $(if ($OidcFlow) { 'OpenID Connect' } else { 'SAML' }) | Write-Verbose

    try {
        # Extract flowId from URL first (URL already contains it)
        $flowId = $null
        if ($SAMLRedirectUrl -match 'flowId=([^&]+)') {
            $flowId = $matches[1]
            "[{0}] Extracted flowId from URL: {1}" -f $functionName, $flowId | Write-Verbose
        }

        if (-not $flowId) {
            Write-Error "Could not extract flowId from SAML redirect URL" -ErrorAction Stop
        }

        # Now follow the redirect to establish session and capture cookies
        # Use -MaximumRedirection 5 to follow redirects automatically
        $redirectResponse = Invoke-WebRequest -Uri $SAMLRedirectUrl -Method GET -WebSession $Session -MaximumRedirection 5 -ErrorAction Stop

        $finalUrl = if ($redirectResponse.BaseResponse.ResponseUri) { 
            $redirectResponse.BaseResponse.ResponseUri.AbsoluteUri 
        }
        else { 
            $SAMLRedirectUrl 
        }
                    
        "[{0}] Followed redirect to: {1}" -f $functionName, $finalUrl | Write-Verbose
                    
        # Verify we reached the signon page
        if ($finalUrl -notmatch "apps\.pingone\.$pingRegion.*signon") {
            "[{0}] Warning: Did not reach expected signon page. Got: {1}" -f $functionName, $finalUrl | Write-Verbose
        }

        # Check and log cookies after redirect
        $cookieCount = ($Session.Cookies.GetCookies($authBaseUrl) | Measure-Object).Count
        "[{0}] After redirect, session has {1} cookies for auth.pingone.{2}" -f $functionName, $cookieCount, $pingRegion | Write-Verbose
                    
        # If no cookies, this might be a WebSession recreation issue - warn but continue
        if ($cookieCount -eq 0) {
            "[{0}] WARNING: No ST cookies found in session. This may cause authentication to fail." -f $functionName | Write-Verbose
            "[{0}] This often happens when PowerShell recreates the WebSession between requests." -f $functionName | Write-Verbose
        }
    }
    catch {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
        }
        "[{0}] Failed to extract flowId: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
        Write-Error "Could not extract flowId from SAML redirect. $($_.Exception.Message)" -ErrorAction Stop
    }
    #EndRegion STEP 1
                
    #Region STEP 2: Submit username to PingOne flows API
    "[{0}] Step 2: Submitting username to PingOne" -f $functionName | Write-Verbose

    # Log current cookies in session for debugging
    $cookieCount = ($Session.Cookies.GetCookies($authBaseUrl) | Measure-Object).Count
    "[{0}] Session has {1} cookies for auth.pingone.{2}" -f $functionName, $cookieCount, $pingRegion | Write-Verbose
    if ($cookieCount -gt 0) {
        $Session.Cookies.GetCookies($authBaseUrl) | ForEach-Object {
            "[{0}]   Cookie: {1}" -f $functionName, $_.Name | Write-Verbose
        }
    }

    # Extract username from email if needed (PingOne expects "username", not "username@company.com")
    $usernameOnly = $Username
    if ($Username -match '^([^@]+)@') {
        $usernameOnly = $matches[1]
        "[{0}] Extracted the username part from the email address '{1}'" -f $functionName, (Format-HPERedactedText -Text $Username) | Write-Verbose
    }

    $flowUrl = "$authBaseUrl/$EnvironmentId/flows/$flowId"
    $appsBaseUrl = $authBaseUrl -replace '^https://auth\.', 'https://apps.'
    $hasPingIDLink = $false

    # Step 2a: GET the flow to discover what authentication type PingOne requires
    "[{0}] Step 2a: GET flow status from PingOne" -f $functionName | Write-Verbose
    $getHeaders = @{
        "Content-Type" = "application/json"
        "Accept"       = "*/*"
        "Origin"       = $appsBaseUrl
        "Referer"      = "$appsBaseUrl/"
    }
    try {
        $flowStatusResponse = Invoke-RestMethod -Uri $flowUrl -Method GET -Headers $getHeaders -WebSession $Session -ErrorAction Stop
        $flowStatus = $flowStatusResponse.status
        "[{0}] Flow status: {1}" -f $functionName, $flowStatus | Write-Verbose
        "[{0}] Flow response: {1}" -f $functionName, ($flowStatusResponse | ConvertTo-Json -Depth 5) | ForEach-Object { Format-HPERedactedText -Text $_ } | Write-Verbose
    }
    catch {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
        }
        Write-Error "Could not retrieve PingOne flow status for '$Username'. $($_.Exception.Message)" -ErrorAction Stop
    }

    if ($flowStatus -eq 'USERNAME_PASSWORD_REQUIRED') {
        "[{0}] PingOne requires username+password authentication." -f $functionName | Write-Verbose

        if (-not $Password) {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
            }
            # The IdP confirmed this account is password-based — record the rejection as password-based for telemetry.
            $Global:HPESSOPasswordSubmitted = $true
            Write-Error @"
Authentication failed: '$Username' is configured for password-based authentication in PingID, not passwordless.

Your Identity Provider (PingID) requires a password for this account.
Use -Credential instead:

   `$cred = Get-Credential -UserName '$Username'
   Connect-HPEGL -Credential `$cred
"@ -ErrorAction Stop
        }

        # Submit username + password in a single step using the content-type the browser uses
        $plainPwd = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
        $credBody = @{ username = $usernameOnly; password = $plainPwd } | ConvertTo-Json
        $plainPwd = [string]::new('0', $plainPwd.Length); $plainPwd = $null
        $credHeaders = @{
            "Content-Type" = "application/vnd.pingidentity.usernamePassword.check+json"
            "Accept"       = "*/*"
            "Origin"       = $appsBaseUrl
            "Referer"      = "$appsBaseUrl/"
        }
        try {
            # Password is about to be submitted to PingID — flag this connection as genuinely
            # password-based for telemetry (set before the POST so a rejected/bad password still counts).
            $Global:HPESSOPasswordSubmitted = $true
            $userLookupResponse = Invoke-RestMethod -Uri $flowUrl -Method POST -Headers $credHeaders -Body $credBody -WebSession $Session -ErrorAction Stop
            "[{0}] Credentials submitted. Flow status: {1}" -f $functionName, $userLookupResponse.status | Write-Verbose
        }
        catch {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
            }
            Write-Error "Authentication failed: PingID rejected the credentials for '$Username'. Verify username and password. Error: $($_.Exception.Message)" -ErrorAction Stop
        }

        if ($userLookupResponse.status -eq 'COMPLETED') {
            $skipToSamlResume = $true
            "[{0}] Authentication COMPLETED — proceeding directly to SAML resume." -f $functionName | Write-Verbose
        }
        elseif ($userLookupResponse._links -and $userLookupResponse._links.'pingid.authentication') {
            $hasPingIDLink = $true
            "[{0}] Password accepted — PingID MFA step-up required." -f $functionName | Write-Verbose
        }
        else {
            # Unexpected status — proceed to SAML resume
            $skipToSamlResume = $true
            "[{0}] Unexpected post-credential status '{1}' — proceeding to SAML resume." -f $functionName, $userLookupResponse.status | Write-Verbose
        }
    }
    else {
        # Passwordless or other flow — submit username for MFA challenge
        "[{0}] Step 2b: Passwordless flow (status: {1}) — submitting username for MFA challenge." -f $functionName, $flowStatus | Write-Verbose

        if ($Password) {
            Write-Warning @"
Your PingID account uses passwordless authentication. The provided password will not be used — attempting SSO (push/TOTP) authentication instead.
To avoid this warning, use -PasswordlessSSOEmail instead of -Credential.
"@
        }

        $payload = @{ username = $usernameOnly } | ConvertTo-Json -Depth 10
        $lookupHeaders = @{
            "Content-Type" = "application/vnd.pingidentity.user.lookup+json"
            "Accept"       = "*/*"
            "Origin"       = $appsBaseUrl
            "Referer"      = "$appsBaseUrl/"
        }
        try {
            $userLookupResponse = Invoke-RestMethod -Uri $flowUrl -Method POST -Headers $lookupHeaders -Body $payload -WebSession $Session -ErrorAction Stop
            "[{0}] Username submitted successfully (passwordless)." -f $functionName | Write-Verbose
            "[{0}] Response: {1}" -f $functionName, ($userLookupResponse | ConvertTo-Json -Depth 5) | ForEach-Object { Format-HPERedactedText -Text $_ } | Write-Verbose

            if ($userLookupResponse._links -and $userLookupResponse._links.'pingid.authentication') {
                $hasPingIDLink = $true
                "[{0}] Confirmed PingID passwordless authentication link present." -f $functionName | Write-Verbose
            }
            if (-not $hasPingIDLink) {
                "[{0}] WARNING: No PingID authentication link found in response." -f $functionName | Write-Verbose
            }
        }
        catch {
            $errorDetails = $_.Exception.Message
            $serverErrorBody = $null
            if ($_.Exception.Response) {
                try {
                    $errorStream = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($errorStream)
                    $serverErrorBody = $reader.ReadToEnd()
                    $reader.Close()
                    "[{0}] Server response body: {1}" -f $functionName, $serverErrorBody | Write-Verbose
                }
                catch { }
            }
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
            }
            if ($serverErrorBody) {
                Write-Error @"
User authentication failed for '$Username'.

This error can occur for multiple reasons:

1. User account does not exist in PingOne environment $EnvironmentId
2. User account is disabled or locked
3. User is not assigned to the HPE GreenLake application in PingOne
   - Contact your PingOne administrator to verify application access
   - Ensure you have the required app role assignments

Additional error details: $errorDetails

Server response: 
$serverErrorBody

For complete PingIdentity setup prerequisites, see: $script:HelpUrl
"@ -ErrorAction Stop
            }
            else { throw }
        }
    }
    #EndRegion STEP 2                

    # STEPs 3-7 drive PingID push/OTP MFA. Skipped when password-only auth completes without MFA step-up.
    if (-not $skipToSamlResume) {

        #Region STEP 3: Initiate PingID authentication
        "[{0}] Step 3: Initiating PingID authentication" -f $functionName | Write-Verbose

        # Extract necessary parameters from HAL response
        # PingOne uses HAL (Hypertext Application Language) format with _links
        $idpAccountId = $null
        $ppmRequest = $null

        # Check if response has _links.pingid.authentication.href (HAL format)
        if ($userLookupResponse._links -and $userLookupResponse._links.'pingid.authentication' -and $userLookupResponse._links.'pingid.authentication'.href) {
            $authUrl = $userLookupResponse._links.'pingid.authentication'.href
            "[{0}] Found PingID authentication URL in HAL _links: {1}" -f $functionName, $authUrl | ForEach-Object { Format-HPERedactedText -Text $_ } | Write-Verbose
                                
            # Extract idp_account_id and ppm_request from query parameters
            if ($authUrl -match '[?&]idp_account_id=([^&]+)') {
                $idpAccountId = $matches[1]
                "[{0}] Extracted idpAccountId from URL: {1}" -f $functionName, $idpAccountId | Write-Verbose
            }
                                
            if ($authUrl -match '[?&]ppm_request=([^&]+)') {
                $ppmRequest = $matches[1]
                "[{0}] Extracted ppmRequest from URL (length: {1})" -f $functionName, $ppmRequest.Length | Write-Verbose
            }
        }
        else {
            # Fallback: try direct properties (older format)
            $idpAccountId = $userLookupResponse.idpAccountId
            $ppmRequest = $userLookupResponse.ppmRequest
                                
            if ($idpAccountId -and $ppmRequest) {
                "[{0}] Extracted parameters from direct properties (legacy format)" -f $functionName | Write-Verbose
            }
        }

        if (-not $idpAccountId -or -not $ppmRequest) {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
            }
                                
            # Enhanced diagnostics
            "[{0}] ERROR: Could not extract required parameters from response" -f $functionName | Write-Verbose
            "[{0}]   Response format: {1}" -f $functionName, ($userLookupResponse | ConvertTo-Json -Depth 2) | ForEach-Object { Format-HPERedactedText -Text $_ } | Write-Verbose
            "[{0}]   idpAccountId found: {1}" -f $functionName, ($null -ne $idpAccountId) | Write-Verbose
            "[{0}]   ppmRequest found: {1}" -f $functionName, ($null -ne $ppmRequest) | Write-Verbose

            $errorMessage = @"
PingID passwordless authentication is not enabled for this account.

This error can occur for multiple reasons:

1. PingID MFA is not configured for this user in environment $EnvironmentId
   - Install PingID on your mobile device
   - Enroll PingID through your organization's PingOne portal
   - Ensure push notifications are enabled for PingID
   - Verify PingOne authentication policy requires PingID (not password)
   - Test the enrollment by signing in through a web browser first

2. User is not assigned to the HPE GreenLake application in PingOne
   - Contact your PingOne administrator to verify application access
   - Ensure you have the required app role assignments

For complete PingIdentity setup prerequisites, see: $script:HelpUrl
"@
            Write-Error $errorMessage -ErrorAction Stop
        }

        # POST to authenticator.pingone.com to initiate PingID auth
        $pingIdAuthUrl = "$authenticatorBaseUrl/pingid/ppm/auth"
        $authBody = "iss=PingOneV2&idp_account_id=$idpAccountId&ppm_request=$ppmRequest"
        $headers = @{
            "Content-Type" = "application/x-www-form-urlencoded"
            "Accept"       = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        }

        try {
            $pingIdAuthResponse = Invoke-WebRequest -Uri $pingIdAuthUrl -Method POST -ErrorAction Stop `
                -Headers $headers -Body $authBody -WebSession $Session

            "[{0}] PingID authentication initiated" -f $functionName | Write-Verbose
        }
        catch {
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
            }
            "[{0}] Failed to initiate PingID authentication: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
            Write-Error "Could not initiate PingID authentication. $($_.Exception.Message)" -ErrorAction Stop
        }
        #EndRegion STEP 3

        #Region STEP 4: Submit WebAuthn capabilities
        "[{0}] Step 4: Submitting WebAuthn capabilities" -f $functionName | Write-Verbose

        $webAuthnBody = "isWebAuthnSupportedByBrowser=true&isWebAuthnPlatformAuthenticatorAvailable=false&isWebAuthnTimeout=false"
        $headers = @{
            "Content-Type" = "application/x-www-form-urlencoded"
            "Accept"       = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        }

        $webAuthnResponse = $null
        try {
            $webAuthnResponse = Invoke-WebRequest -Uri $pingIdAuthUrl -Method POST -ErrorAction Stop `
                -Headers $headers -Body $webAuthnBody -WebSession $Session

            "[{0}] WebAuthn capabilities submitted" -f $functionName | Write-Verbose
        }
        catch {
            # Non-critical error, continue with initial response
            "[{0}] Warning: Failed to submit WebAuthn capabilities: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
        }
        #EndRegion STEP 4

        #Region STEP 5: Determine authentication method and handle accordingly
        "[{0}] Step 5: Determining authentication method" -f $functionName | Write-Verbose

        # Extract CSRF token - try WebAuthn response first (Step 4), then initial response (Step 3)
        # The CSRF token location varies by PingOne environment configuration
        $csrfToken = $null
        $responseToSearch = if ($webAuthnResponse) { $webAuthnResponse.Content } else { $pingIdAuthResponse.Content }
        $responseSource = if ($webAuthnResponse) { "WebAuthn response" } else { "initial auth response" }
                
        # Try multiple regex patterns to extract CSRF token
        if ($responseToSearch -match 'csrfToken["\s]*[:=]["\s]*["'']([^"'']+)["'']') {
            $csrfToken = $matches[1]
            "[{0}] Extracted CSRF token from {1} (pattern 1): [REDACTED, {2} chars]" -f $functionName, $responseSource, $csrfToken.Length | Write-Verbose
        }
        elseif ($responseToSearch -match 'name="csrfToken"[^>]*value="([^"]+)"') {
            $csrfToken = $matches[1]
            "[{0}] Extracted CSRF token from {1} (pattern 2 - hidden input): [REDACTED, {2} chars]" -f $functionName, $responseSource, $csrfToken.Length | Write-Verbose
        }
        elseif ($responseToSearch -match 'data-csrf-token="([^"]+)"') {
            $csrfToken = $matches[1]
            "[{0}] Extracted CSRF token from {1} (pattern 3 - data attribute): [REDACTED, {2} chars]" -f $functionName, $responseSource, $csrfToken.Length | Write-Verbose
        }
        elseif ($responseToSearch -match 'csrf[_-]?token["\s]*[:=]["\s]*["'']([^"'']+)["'']') {
            $csrfToken = $matches[1]
            "[{0}] Extracted CSRF token from {1} (pattern 4 - flexible): [REDACTED, {2} chars]" -f $functionName, $responseSource, $csrfToken.Length | Write-Verbose
        }
        else {
            # CSRF token not found - this might be OK if PingOne doesn't require it for the response page
            "[{0}] WARNING: Could not extract CSRF token from {1}" -f $functionName, $responseSource | Write-Verbose
            "[{0}] Will attempt to retrieve tokens without CSRF token" -f $functionName | Write-Verbose
        }
                
        # Extract number challenge from WebAuthn response (Step 4) if available
        # Number challenge appears AFTER WebAuthn submission, not in initial response
        $numberChallenge = $null
        $numberResponseContent = if ($webAuthnResponse) { $webAuthnResponse.Content } else { $pingIdAuthResponse.Content }
                
        if ($numberResponseContent -match '<div\s+class="numbermatching">(\d+)</div>') {
            $numberChallenge = $matches[1]
            "[{0}] Detected number matching challenge: {1}" -f $functionName, $numberChallenge | Write-Verbose
        }
        elseif ($numberResponseContent -match 'data-challenge-number["\s]*[:=]["\s]*["''](\d+)["'']') {
            $numberChallenge = $matches[1]
            "[{0}] Detected number matching challenge: {1}" -f $functionName, $numberChallenge | Write-Verbose
        }
        elseif ($numberResponseContent -match 'challenge["\s]*[:=]["\s]*["''](\d+)["'']') {
            $numberChallenge = $matches[1]
            "[{0}] Detected number matching challenge: {1}" -f $functionName, $numberChallenge | Write-Verbose
        }
                
        # Check OTP availability and policy enforcement
        # Use WebAuthn response (Step 4) to check for OTP option and policy restrictions
        $responseContent = if ($webAuthnResponse) { $webAuthnResponse.Content } else { $pingIdAuthResponse.Content }
        $hasOtpOption = $responseContent -match 'use.*code|enter.*code|otp|passcode|data-use-code'
                
        # Check if OTP-only is enforced by policy (push disabled)
        # Policy OTP can be detected by specific HTML elements or data attributes in the response
        $otpOnlyByPolicy = $responseContent -match 'data-policy["\s]*[:=]["\s]*["'']otp["'']|policy["\s]*[:=]["\s]*["'']OTP["'']|otpOnly["\s]*[:=]["\s]*true'
                
        # If HTML detection didn't find policy enforcement, do a quick status check
        # This catches POLICY_OTP that's only visible via status endpoint
        if (-not $otpOnlyByPolicy -and $hasOtpOption) {
            "[{0}] Performing quick status check to detect OTP-only policy..." -f $functionName | Write-Verbose
            try {
                $statusUrl = "$authenticatorBaseUrl/pingid/ppm/auth/status"
                $timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
                $quickStatusCheck = Invoke-RestMethod -Uri "$statusUrl`?_=$timestamp" -Method GET -ErrorAction Stop `
                    -Headers @{"Accept" = "*/*" } -WebSession $Session
                        
                "[{0}] Quick status response: {1}" -f $functionName, ($quickStatusCheck | ConvertTo-Json) | ForEach-Object { Format-HPERedactedText -Text $_ } | Write-Verbose
                        
                if ($quickStatusCheck.status -eq "POLICY_OTP") {
                    $otpOnlyByPolicy = $true
                    "[{0}] Detected POLICY_OTP via status check - OTP enforced by policy" -f $functionName | Write-Verbose
                }
            }
            catch {
                "[{0}] Quick status check failed: {1} - will proceed with default detection" -f $functionName, $_.Exception.Message | Write-Verbose
            }
        }
                
        # Determine authentication method to use
        # Push notification is the default and primary method
        # OTP is used if: 1) enforced by policy, 2) push unavailable, or 3) user preference (not implemented)
        $useOtp = $false
        $pushAvailable = -not ($responseContent -match 'push.*not.*available|push.*unavailable|no.*device')
                
        if ($otpOnlyByPolicy) {
            # OTP enforced by administrator policy
            $useOtp = $true
            "[{0}] Selected method: OTP code (enforced by policy - push disabled by administrator)" -f $functionName | Write-Verbose
        }
        elseif ($pushAvailable) {
            # Push is available and will be used (default)
            "[{0}] Selected method: Push notification (default)" -f $functionName | Write-Verbose
        }
        elseif ($hasOtpOption) {
            # Push not available, automatic fallback to OTP
            $useOtp = $true
            "[{0}] Selected method: OTP code (push not available, automatic fallback)" -f $functionName | Write-Verbose
        }
        else {
            # Neither method available
            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
            }
            Write-Error "Neither push nor OTP authentication available. For PingOne setup prerequisites, see: $($script:HelpUrl)" -ErrorAction Stop
        }
        #EndRegion STEP 5

        #Region STEP 6: Handle OTP Code Input (if selected)
        if ($useOtp) {
            "[{0}] Step 6: Handling OTP code authentication" -f $functionName | Write-Verbose

            $otpCode = Read-Host -Prompt "Enter your PingID OTP code for $($Username)"

            if ([string]::IsNullOrWhiteSpace($otpCode)) {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                }
                Write-Error "OTP code is required" -ErrorAction Stop
            }

            # Submit OTP code
            $otpSubmitUrl = "$authenticatorBaseUrl/pingid/ppm/auth/otp"
            $otpBody = "otp=$otpCode&csrfToken=$csrfToken"
                    
            $headers = @{
                "Content-Type" = "application/x-www-form-urlencoded"
                "Accept"       = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
            }

            try {
                $otpResponse = Invoke-WebRequest -Uri $otpSubmitUrl -Method POST -ErrorAction Stop `
                    -Headers $headers -Body $otpBody -WebSession $Session

                "[{0}] OTP code submitted successfully" -f $functionName | Write-Verbose

                # Extract JWT tokens from OTP response
                $ppmRequest = $null
                $ppmResponse = $null

                if ($otpResponse.Content -match 'name="ppm_request"[^>]*value="([^"]+)"') {
                    $ppmRequest = $matches[1]
                    "[{0}] Extracted ppm_request token from OTP response" -f $functionName | Write-Verbose
                }

                if ($otpResponse.Content -match 'name="ppm_response"[^>]*value="([^"]+)"') {
                    $ppmResponse = $matches[1]
                    "[{0}] Extracted ppm_response token from OTP response" -f $functionName | Write-Verbose
                }

                if (-not $ppmRequest -or -not $ppmResponse) {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                    }
                    Write-Error "Could not extract JWT tokens from OTP response" -ErrorAction Stop
                }

                # Skip to callback step
                "[{0}] OTP authentication completed, proceeding to callback" -f $functionName | Write-Verbose
            }
            catch {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                }

                $errorMessage = "Invalid OTP code. Please verify the code and try again"
                        
                if ($_.Exception.Response) {
                    try {
                        $errorStream = $_.Exception.Response.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($errorStream)
                        $errorBody = $reader.ReadToEnd()
                        $reader.Close()
                                
                        if ($errorBody -match 'error|invalid|incorrect') {
                            $errorMessage = $errorBody
                        }
                    }
                    catch { 
                        # Intentionally ignore - response stream may not be readable
                    }
                }

                "[{0}] Failed to submit OTP code: {1}" -f $functionName, $errorMessage | Write-Verbose
                throw "Authentication failed: The verification code was rejected by PingID. Verify the current code in your authenticator app and try again."
            }
        }
        else {
            # Continue with push notification flow
            "[{0}] Step 6: Polling for push approval" -f $functionName | Write-Verbose

            Start-Sleep -Milliseconds 500

            # Show appropriate progress message based on number challenge
            if ($numberChallenge) {
                if ($NoProgress) {
                    Write-Host "`n  Action required: Open PingID and select the number " -NoNewline -ForegroundColor Cyan
                    Write-Host $numberChallenge -ForegroundColor Yellow -NoNewline
                    Write-Host " to authenticate.`n" -ForegroundColor Cyan
                }
                else {
                    Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                        -CurrentActivity "Respond '$numberChallenge' to the PingID notification" -Id 0
                }
                "[{0}] Number challenge active - user must select: {1}" -f $functionName, $numberChallenge | Write-Verbose
            }
            else {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                        -CurrentActivity "Waiting for PingID authentication..." -Id 0
                }
            }

            "[{0}] Initiating authentication request..." -f $functionName | Write-Verbose
            "[{0}] Waiting for authentication approval (timeout: {1} minutes)..." -f $functionName, $TimeoutMinutes | Write-Verbose

            # Poll the status endpoint until approved
            $statusUrl = "$authenticatorBaseUrl/pingid/ppm/auth/status"
            $timeout = [datetime]::Now.AddMinutes($TimeoutMinutes)
            $approved = $false
            $timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
            $firstPoll = $true
            $unknownStatusCount = 0

            $headers = @{
                "Accept" = "*/*"
            }

            do {
                Start-Sleep -Seconds $PollIntervalSeconds

                try {
                    # Poll status with timestamp to prevent caching
                    $statusCheckUrl = "$statusUrl`?_=$timestamp"
                    $statusResponse = Invoke-RestMethod -Uri $statusCheckUrl -Method GET -ErrorAction Stop `
                        -Headers $headers -WebSession $Session

                    "[{0}] Status poll response: {1}" -f $functionName, ($statusResponse | ConvertTo-Json) | ForEach-Object { Format-HPERedactedText -Text $_ } | Write-Verbose

                    # Check if authentication is complete
                    if ($statusResponse.status -eq "OK" -or $statusResponse.status -eq "SUCCESS") {
                        $approved = $true
                        "[{0}] Push notification approved!" -f $functionName | Write-Verbose
                        break
                    }
                    elseif ($statusResponse.status -eq "ASYNC_AUTH_WAIT" -or $statusResponse.status -eq "WAITING") {
                        # Still waiting for user approval - reset the unknown-status guard counter
                        $unknownStatusCount = 0
                        # update message on first wait to confirm push was sent
                        if ($firstPoll) {
                            "[{0}] Push notification confirmed - sent to mobile device" -f $functionName | Write-Verbose
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps -and -not $numberChallenge) {
                                Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                                    -CurrentActivity "Approve the PingID push notification" -Id 0
                            }
                            $firstPoll = $false
                        }
                        else {
                            "[{0}] Still waiting for approval..." -f $functionName | Write-Verbose
                        }
                    }
                    elseif ($statusResponse.status -eq "POLICY_OTP") {
                        # Policy requires OTP only - push is disabled by administrator
                        "[{0}] Server reported POLICY_OTP status - push disabled by policy, switching to OTP" -f $functionName | Write-Verbose
                                
                        # Prompt for OTP code
                        $otpCode = Read-Host -Prompt "Enter your PingID OTP code for $($Username)"
                                
                        if ([string]::IsNullOrWhiteSpace($otpCode)) {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                            }
                            Write-Error "OTP code is required" -ErrorAction Stop
                        }
                                
                        # Submit OTP code
                        $otpSubmitUrl = "$authenticatorBaseUrl/pingid/ppm/auth/otp"
                        $otpBody = "otp=$otpCode&csrfToken=$csrfToken"
                                
                        $otpHeaders = @{
                            "Content-Type" = "application/x-www-form-urlencoded"
                            "Accept"       = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
                        }
                                
                        try {
                            $otpResponse = Invoke-WebRequest -Uri $otpSubmitUrl -Method POST -ErrorAction Stop `
                                -Headers $otpHeaders -Body $otpBody -WebSession $Session
                                    
                            "[{0}] OTP code submitted successfully" -f $functionName | Write-Verbose
                                    
                            # Extract JWT tokens from OTP response
                            if ($otpResponse.Content -match 'name="ppm_request"[^>]*value="([^"]+)"') {
                                $ppmRequest = $matches[1]
                                "[{0}] Extracted ppm_request token from OTP response" -f $functionName | Write-Verbose
                            }
                                    
                            if ($otpResponse.Content -match 'name="ppm_response"[^>]*value="([^"]+)"') {
                                $ppmResponse = $matches[1]
                                "[{0}] Extracted ppm_response token from OTP response" -f $functionName | Write-Verbose
                            }
                                    
                            if (-not $ppmRequest -or -not $ppmResponse) {
                                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                    Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                                }
                                Write-Error "Could not extract JWT tokens from OTP response" -ErrorAction Stop
                            }
                                    
                            # Mark as approved to exit polling loop
                            $approved = $true
                            "[{0}] OTP authentication completed" -f $functionName | Write-Verbose
                            break
                        }
                        catch {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                            }
                                    
                            $errorMessage = "Invalid OTP code. Please verify the code and try again"
                            if ($_.Exception.Response) {
                                try {
                                    $errorStream = $_.Exception.Response.GetResponseStream()
                                    $reader = New-Object System.IO.StreamReader($errorStream)
                                    $errorBody = $reader.ReadToEnd()
                                    $reader.Close()
                                    if ($errorBody -match 'error|invalid|incorrect') {
                                        $errorMessage = $errorBody
                                    }
                                }
                                catch { 
                                    # Intentionally ignore - response stream may not be readable
                                }
                            }
                                    
                            "[{0}] Failed to submit OTP code: {1}" -f $functionName, $errorMessage | Write-Verbose
                            throw "Authentication failed: The verification code was rejected by PingID. Verify the current code in your authenticator app and try again."
                        }
                    }
                    elseif ($statusResponse.status -eq "TIMEOUT" -or $statusResponse.status -eq "AUTH_OTP") {
                        "[{0}] Server reported {1} status - push notification timed out" -f $functionName, $statusResponse.status | Write-Verbose
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                        }
                        Write-Error "PingID push notification timed out. The authentication request expired before approval." -ErrorAction Stop
                    }
                    elseif ($statusResponse.status -eq "DENY" -or $statusResponse.status -eq "DENIED" -or $statusResponse.status -eq "NUMBER_MATCHING_DENY" -or $statusResponse.status -eq "FAILED") {
                        "[{0}] Push notification was denied or failed (status: {1})" -f $functionName, $statusResponse.status | Write-Verbose
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                        }
                        Write-Error "PingID push notification was denied. The user either tapped 'No' or selected the wrong number on the PingID prompt. Please try again and approve the request on your device." -ErrorAction Stop
                    }
                    elseif ($statusResponse.status -eq "INVALID_INPUT") {
                        "[{0}] Server returned INVALID_INPUT status - policy restriction detected" -f $functionName | Write-Verbose
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                        }
                        Write-Error "A company policy is preventing you from authenticating with PingID at this time. Contact your administrator." -ErrorAction Stop
                    }
                    else {
                        # Unrecognized status - guard against an unsupported PingID MFA challenge.
                        # A few consecutive unknown statuses are tolerated to absorb transient/intermediate
                        # server states, but a persistent unknown status means the challenge shape is one
                        # this module does not yet handle (rather than silently hanging until timeout).
                        $unknownStatusCount++
                        "[{0}] Unrecognized PingID status '{1}' (occurrence {2})" -f $functionName, $statusResponse.status, $unknownStatusCount | Write-Verbose
                        if ($unknownStatusCount -ge 3) {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                            }
                            Write-Error @"
Authentication failed: Unrecognized PingID MFA challenge (status: '$($statusResponse.status)').

This PingID authentication method is not yet supported by the module. To help add support,
please capture a HAR file of the sign-in (browser DevTools > Network > 'Export HAR') and open
an issue at: $($script:HelpUrl)
"@ -ErrorAction Stop
                        }
                    }
                }
                catch {
                    # Check if this is a status-related throw (TIMEOUT, AUTH_OTP, DENIED, REJECTED, FAILED, POLICY) - rethrow it
                    if ($_.Exception.Message -match "timed out|denied|rejected|failed|policy|OTP code") {
                        throw
                    }
                    # Otherwise it's a network/connectivity error - log and continue polling
                    "[{0}] Status poll error: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                }

                # Check for timeout
                if ([datetime]::Now -ge $timeout) {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                    }
                    Write-Error @"
Timeout! PingID push notification was not approved within $TimeoutMinutes minutes.

Please try again and approve the request promptly.
"@ -ErrorAction Stop
                }

                $timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
                        
            } while (-not $approved)

            # Retrieve JWT tokens from response page (for push)
            # Skip if tokens were already retrieved (e.g., from POLICY_OTP handling)
            if (-not $ppmRequest -or -not $ppmResponse) {
                "[{0}] Retrieving authentication tokens from response page" -f $functionName | Write-Verbose

                # Build the response page URL - CSRF token may or may not be required
                if ($csrfToken) {
                    "[{0}] Using CSRF token: [REDACTED, {1} chars]" -f $functionName, $csrfToken.Length | Write-Verbose
                    $responsePageUrl = "$authenticatorBaseUrl/pingid/ppm/auth/response?csrfToken=$csrfToken&status=OK&getStatusResponse=%7B%22status%22%3A%22OK%22%7D"
                }
                else {
                    "[{0}] No CSRF token available - attempting without it" -f $functionName | Write-Verbose
                    $responsePageUrl = "$authenticatorBaseUrl/pingid/ppm/auth/response?status=OK&getStatusResponse=%7B%22status%22%3A%22OK%22%7D"
                }
                        
                try {
                    $tokenResponse = Invoke-WebRequest -Uri $responsePageUrl -Method GET -ErrorAction Stop `
                        -WebSession $Session -UseBasicParsing

                    "[{0}] Retrieved authentication response page" -f $functionName | Write-Verbose

                    # Extract ppm_request and ppm_response from hidden form fields
                    if ($tokenResponse.Content -match 'name="ppm_request"[^>]*value="([^"]+)"') {
                        $ppmRequest = $matches[1]
                        "[{0}] Extracted ppm_request token" -f $functionName | Write-Verbose
                    }

                    if ($tokenResponse.Content -match 'name="ppm_response"[^>]*value="([^"]+)"') {
                        $ppmResponse = $matches[1]
                        "[{0}] Extracted ppm_response token" -f $functionName | Write-Verbose
                    }

                    if (-not $ppmRequest -or -not $ppmResponse) {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                        }
                        Write-Error "Could not extract JWT tokens from authentication response" -ErrorAction Stop
                    }
                }
                catch {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                    }
                    "[{0}] Failed to retrieve tokens: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    Write-Error "Could not retrieve authentication tokens. $($_.Exception.Message)" -ErrorAction Stop
                }
            }
            else {
                "[{0}] Tokens already retrieved (from POLICY_OTP handling), skipping response page" -f $functionName | Write-Verbose
            }
        }
        #EndRegion STEP 6

        #Region STEP 7: Post callback with JWT tokens
        "[{0}] Step 7: Posting authentication callback" -f $functionName | Write-Verbose

        $callbackUrl = "$authBaseUrl/$EnvironmentId/flows/$flowId/pingIDAuthenticationCallback"
        $callbackBody = "ppm_request=$ppmRequest&ppm_response=$ppmResponse"
                
        $headers = @{
            "Content-Type" = "application/x-www-form-urlencoded"
            "Accept"       = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
        }

        try {
            # This should return a 302 redirect to the SAML resume URL
            $callbackResponse = Invoke-WebRequest -Uri $callbackUrl -Method POST -ErrorAction Stop `
                -Headers $headers -Body $callbackBody -WebSession $Session -MaximumRedirection 0

            "[{0}] Callback posted (Status: {1})" -f $functionName, $callbackResponse.StatusCode | Write-Verbose
        }
        catch {
            # 302 redirect is expected, catch it to get the Location header
            if ($_.Exception.Response.StatusCode -eq 302) {
                "[{0}] Received expected 302 redirect" -f $functionName | Write-Verbose
            }
            else {
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                }
                Write-Error "Callback post failed. $($_.Exception.Message)" -ErrorAction Stop
            }
        }
        #EndRegion STEP 7

    } # end if (-not $skipToSamlResume)

    #Region STEP 8: Resume the flow and retrieve the response (SAML response, or redirect back to HPE for OIDC)
    $resumeKind = if ($OidcFlow) { 'OpenID Connect' } else { 'SAML' }
    "[{0}] Step 8: Resuming {1} flow" -f $functionName, $resumeKind | Write-Verbose

    $resumeUrl = if ($OidcFlow) { "$authBaseUrl/$EnvironmentId/as/resume?flowId=$flowId" } else { "$authBaseUrl/$EnvironmentId/saml20/resume?flowId=$flowId" }

    try {
        # OIDC: the resume redirects back through HPE GreenLake (about five hops) before reaching the HPE sign-in page.
        $samlResumeResponse = Invoke-WebRequest -Uri $resumeUrl -Method GET -WebSession $Session -UseBasicParsing -MaximumRedirection 10 -ErrorAction Stop

        "[{0}] {1} flow resumed successfully" -f $functionName, $resumeKind | Write-Verbose
        "[{0}] Authentication completed" -f $functionName | Write-Verbose

        if ($CompletedSteps) { $CompletedSteps.Value++ }
        return $samlResumeResponse
    }
    catch {
        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
            Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
        }
        Write-Error "Could not resume $resumeKind flow. $($_.Exception.Message)" -ErrorAction Stop
    }
    #EndRegion STEP 8
}

# NOTE: This file intentionally has NO Export-ModuleMember.
# Utilities.psm1 DOT-SOURCES this file (. "$PSScriptRoot\Auth-SSO.psm1") so the three SSO flow functions
# are defined directly in Utilities' session state, where Connect-HPEGL can call them. An Export-ModuleMember
# call here would break that dot-source (Export-ModuleMember is only valid inside a module import context and
# aborts the dot-source), leaving the functions undefined — which caused the
# "The term 'Invoke-EntraIDSSOAuthentication' is not recognized" failure. The functions stay hidden from end
# users because the manifest's FunctionsToExport does not list them. See the header of this file for details.

# SIG # Begin signature block
# MIIn2gYJKoZIhvcNAQcCoIInyzCCJ8cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCaTzipkofzhnaW
# C3r75g544+Zu1PpC3DCCHXadcFGghaCCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
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
# o/nrPkeemSSU5WDBSjWia63Movtv1T6PgLmyUF7C/LEwDQYJKoZIhvcNAQEBBQAE
# ggIAIITqclNI1lr0QtjzhHihSkBn1DMnfaP2qmMgryzG9Wz9cu+RD3VRDo16lJaU
# joVW9MJoRKCU552IKp8TPud3Szc7IiZ7jJXirpaE0wOXoIzip3m4cEAYlBYqymCb
# 42VIGGNszu2VTctRRlRCPf4Hbbaomh/b1acCGybnamrBIzZHx+wEMnhsKDKp0vms
# xLAYZn62XBb9mg+1VuIMUPXMWOWlZFmlCNSDlH/PnL0TsDKjOzKTuQgu883DajZj
# S0ej0gdZ37EUrIpDYNFEVNwoy7eM1rNSF9gkc6VCam/0C0zF8NxDKA9ruwhLd1Jq
# TRcw8KdPeVXmpaVvu7g0Q7kyMMjAMDqb6cfCpcJLo5MY+5fKOLPdN0r4MePe/2cN
# D408EYVM6Kw2n0/STSoof0osXrUdPScyDbf6mJ01+ta8N13Ce7X7SCRUyJsnj8Ex
# I/3KvHYQTwsSlmNNe9G7DUg7q8pv/bI3XKdnrMpDcCUS5F0yo90wOhHDsC+8AYA6
# 0qsKtjjMfz5KqjYWVQNQQQ9ZICrprnwDjuqFpweZzGRxwKjUvtiaKIffaj1DG9q9
# 9sxHUW5ceDG2ltN/0kGrpW1LFtFZ3TRVX6kUnDR1exSzNW5pSjshPSI7RXTnkFgP
# RWzCOrsTeVqvVyIEIRuFjwjmquICUz8igJvpl/xUwzs6cW6hgheXMIIXkwYKKwYB
# BAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEwDQYJ
# YIZIAWUDBAICBQAEMOQ8XsmOlX5O/m8cJyajQOHV3GQBbFwx5hIwCC7OCMcMa2Z2
# RpVRCKWSwJ5jZ6PLjAIQR6E+QKOPW07U0s04YkQKyxgPMjAyNjExMDQwODE4MzBa
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
# ODMwWjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTpqKcjtIUE9eDhQ4tnPs6HzyxQ
# mzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCBxHdd7HC5xsmHXVY1pnAB3yX0SAzCa
# YI7cEFY0wVBQezA/BgkqhkiG9w0BCQQxMgQw8WbsNNZcI8QlTXyFxwD4rPvPf7cZ
# KN4UUcCvT5ChiANSgCGwYPkZSYTT/tQIEbuMMA0GCSqGSIb3DQEBAQUABIICAFwk
# 4Id3vuNA31jMAxZFpTh2FO+WpjBh/yiKwFTGRPRfQcvwkVmFqqTkKdwpiB2nGa2E
# FYN7OJTMRaCV+GK+f5iuCBQeGaLkxsRt6LEi4jmG5KFHrEWswYl2NsODQzTFE5CT
# XSp5uYKyhY0dEet1eSzMb3Zp8kBk+vBLJqcs9xS+sfGuEX3WzJwt6m18nclI6YLu
# 0DV04JWl3WQamBpfkU0zWyxl3AMtuKips4KbG4s0xnV0XR7cNehIS/8avMgCO/WE
# wnQUmeNptXBLMqoLUdp7XFEFuBHAsOTwd9yrjzX/S8LDDGlsBENocnWxKdlpX+Xg
# glrGRS20L9ANzwT1v7oH9dD6owYYftzIAAIwmXtENOGmnQaCOEoKHuealAz4J8y0
# wyfqUIRnhe2Hc4wivzG1guqLf7ZSV3cykobp/1fPFqbrYQnTiMTTdsSe5/G0Sr7i
# iiHEHL8KNNsamxqkU023/HRMOEMmANxYXLs49aLRcPUHuX6uXsuhpXtZyjFFiOOI
# vwJa68DshW7o/+kp0NA/iKdkqhAWDSxCcwLn4sqrY4z0tGXSyPEqmnkAL8NG04Gp
# 3DMJLyw6MAh0jrl0Ow43X6buv7sQppH+LqogEjhZ21NjylVMBnjw0Ulxm8GVTPSw
# taPlHs8li8A9JAmWbAJtN7LEJ+p4MKinopryQbNF
# SIG # End signature block
