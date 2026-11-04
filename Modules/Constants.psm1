
# Defines constants and getter functions for HPECOMCmdlets module


#Region Base URL endpoints

[String]$script:HPEGLAPIbaseURL = 'https://global.api.greenlake.hpe.com'
function Get-HPEGLAPIbaseURL { if ($Global:HPEGLGlobalApiBaseURL) { $Global:HPEGLGlobalApiBaseURL } else { $script:HPEGLAPIbaseURL } }

# Organizations API
[String]$script:HPEGLAPIOrgbaseURL = 'https://aquila-org-api.common.cloud.hpe.com'
function Get-HPEGLAPIOrgbaseURL { if ($Global:HPEGLOrgApiBaseURL) { $Global:HPEGLOrgApiBaseURL } else { $script:HPEGLAPIOrgbaseURL } }

# Account Management API
[String]$script:HPEGLUIbaseURL = 'https://aquila-user-api.common.cloud.hpe.com'
function Get-HPEGLUIbaseURL { if ($Global:HPEGLUserApiBaseURL) { $Global:HPEGLUserApiBaseURL } else { $script:HPEGLUIbaseURL } }

[String]$script:HPEOnepassbaseURL = 'https://onepass-enduserservice.it.hpe.com'
function Get-HPEOnepassbaseURL {
    # Route to the ITG endpoint when connected to a non-production Okta (e.g. pavo uses auth-itg.hpe.com)
    if ($Global:HPEGLoktaURL -and $Global:HPEGLoktaURL -ne 'https://auth.hpe.com') {
        return 'https://onepass-itg-enduserservice.it.hpe.com'
    }
    $script:HPEOnepassbaseURL
}

#EndRegion


#Region ---------------------------- PUBLIC SPP DOCUMENTATION PATHS (NOT IMPLEMENTED!)-------------------------------------------------------------------------------------------------------------------------------------------

[String]$HpeSppTechLibraryAssetsUri = 'https://support.hpe.com/docs/display/public/a00sppdocen_US/spp/assets'
function Get-HpeSppTechLibraryAssetsUri { $script:HpeSppTechLibraryAssetsUri }

[String]$HpeSupportDocumentApiUri = 'https://support.hpe.com/hpesc/public/api/document'
function Get-HpeSupportDocumentApiUri { $script:HpeSupportDocumentApiUri }

#EndRegion


#Region ---------------------------- COM PATHS -------------------------------------------------------------------------------------------------------------------------------------------

[String]$COMJobTemplatesUri = '/compute-ops-mgmt/v1beta2/job-templates'
function Get-COMJobTemplatesUri { $script:COMJobTemplatesUri }

[String]$COMActivationKeysUri = '/compute-ops-mgmt/v1beta1/activation-keys'
function Get-COMActivationKeysUri { $script:COMActivationKeysUri }

[String]$COMActivitiesUri = '/compute-ops-mgmt/v1beta2/activities'
function Get-COMActivitiesUri { $script:COMActivitiesUri }

[String]$COMApprovalPoliciesUri = '/compute-ops-mgmt/v1beta2/approval-policies'
function Get-COMApprovalPoliciesUri { $script:COMApprovalPoliciesUri }

[String]$COMApprovalRequestsUri = '/compute-ops-mgmt/v1beta2/approval-requests'
function Get-COMApprovalRequestsUri { $script:COMApprovalRequestsUri }

[String]$COMOneViewAppliancesUri = '/compute-ops-mgmt/v1beta1/appliances' 
# [String]$COMOneViewAppliancesUri = '/compute-ops-mgmt/v1beta1/oneview-appliances' # requires OneView Edition subscription
function Get-COMOneViewAppliancesUri { $script:COMOneViewAppliancesUri }

[String]$COMOneViewAppliancesCreateUri = '/compute-ops-mgmt/v1beta1/oneview-appliances'
function Get-COMOneViewAppliancesCreateUri { $script:COMOneViewAppliancesCreateUri }

[String]$COMApplianceFirmwareBundlesUri = '/compute-ops-mgmt/v1beta1/appliance-firmware-bundles'
function Get-COMApplianceFirmwareBundlesUri { $script:COMApplianceFirmwareBundlesUri }

[String]$COMOneViewServerTemplatesUri = '/compute-ops-mgmt/v1beta1/oneview-server-templates'
function Get-COMOneViewServerTemplatesUri { $script:COMOneViewServerTemplatesUri }

[String]$COMExternalServicesUri = '/compute-ops-mgmt/v1beta1/external-services'
function Get-COMExternalServicesUri { $script:COMExternalServicesUri }

[String]$COMFiltersUri = '/compute-ops-mgmt/v1beta1/filters'
function Get-COMFiltersUri { $script:COMFiltersUri }

[String]$COMFirmwareBundlesUri = '/compute-ops-mgmt/v1beta2/firmware-bundles'
function Get-COMFirmwareBundlesUri { $script:COMFirmwareBundlesUri }

[String]$COMGroupsUri = '/compute-ops-mgmt/v1beta3/groups'
function Get-COMGroupsUri { $script:COMGroupsUri }

[String]$COMJobsUri = '/compute-ops-mgmt/v1/jobs'
function Get-COMJobsUri { $script:COMJobsUri }

[String]$COMJobsv1beta3Uri = '/compute-ops-mgmt/v1beta3/jobs'
function Get-COMJobsv1beta3Uri { $script:COMJobsv1beta3Uri }

[String]$COMMetricsConfigurationsUri = '/compute-ops-mgmt/v1/metrics-configurations'
function Get-COMMetricsConfigurationsUri { $script:COMMetricsConfigurationsUri }

[String]$COMReportsUri = '/compute-ops-mgmt/v1beta2/reports'
function Get-COMReportsUri { $script:COMReportsUri }

[String]$COMSchedulesUri = '/compute-ops-mgmt/v1beta2/schedules'
function Get-COMSchedulesUri { $script:COMSchedulesUri }

[String]$COMServerLocationsUri = '/compute-ops-mgmt/v1beta1/server-locations'
function Get-COMServerLocationsUri { $script:COMServerLocationsUri }

[String]$COMSettingsUri = '/compute-ops-mgmt/v1/settings'
function Get-COMSettingsUri { $script:COMSettingsUri }

[String]$COMServersUri = '/compute-ops-mgmt/v1/servers'
function Get-COMServersUri { $script:COMServersUri }

[String]$COMServersUIDoorwayUri = '/ui-doorway/compute/v2/servers'
function Get-COMServersUIDoorwayUri { $script:COMServersUIDoorwayUri }

[String]$COMDiscoveredServersUri = '/compute-ops-mgmt/v1/discovered-servers'
function Get-COMDiscoveredServersUri { $script:COMDiscoveredServersUri }

[String]$COMDiscoveredServersSummaryUri = '/compute-ops-mgmt/v1/discovered-servers/summary'
function Get-COMDiscoveredServersSummaryUri { $script:COMDiscoveredServersSummaryUri }

[String]$COMGroupsUIDoorwayUri = '/ui-doorway/compute/v2/groups'
function Get-COMGroupsUIDoorwayUri { $script:COMGroupsUIDoorwayUri }

[String]$COMUserPreferencesUri = '/compute-ops-mgmt/v1/user-preferences'
function Get-COMUserPreferencesUri { $script:COMUserPreferencesUri }

[String]$COMWebhooksUri = '/compute-ops-mgmt/v1beta1/webhooks'
function Get-COMWebhooksUri { $script:COMWebhooksUri }

function Get-GLWebhooksUri { "$(Get-HPEGLAPIbaseURL)/events/v1beta1/webhooks" }

function Get-GLSubscriptionsUri { "$(Get-HPEGLAPIbaseURL)/events/v1beta1/subscriptions" }

[String]$COMEnergyByEntityUri = '/compute-ops-mgmt/v1beta1/energy-by-entity'
function Get-COMEnergyByEntityUri { $script:COMEnergyByEntityUri }

[String]$COMUtilizationByEntityUri = '/compute-ops-mgmt/v1beta1/utilization-by-entity'
function Get-COMUtilizationByEntityUri { $script:COMUtilizationByEntityUri }

#EndRegion


#Region Telemetry

# Azure Application Insights connection string for anonymous usage telemetry (PRODUCTION resource).
# Telemetry is OFF by default (opt-in). Users opt in via Enable-HPECOMDataCollection (or by setting
# $env:HPE_COM_ENABLE_TELEMETRY = '1'). An explicit opt-out (Disable-HPECOMDataCollection or
# $env:HPE_COM_NO_TELEMETRY = '1') always wins.
[String]$script:HPECOMTelemetryConnectionString = 'InstrumentationKey=ed9990d8-6755-43d3-9d51-79bd5194d60a;IngestionEndpoint=https://westeurope-5.in.applicationinsights.azure.com/;LiveEndpoint=https://westeurope.livediagnostics.monitor.azure.com/;ApplicationId=398913d1-5438-47eb-a6e0-3c19d5a86710'

# Returns the active telemetry connection string. A development/test override is honored first so
# local test runs can be redirected to a separate (test) Application Insights resource without
# editing this module:
#   $env:HPE_COM_TELEMETRY_CONNECTION_STRING = 'InstrumentationKey=...;IngestionEndpoint=...'
# When the override is not set, the shipped PRODUCTION connection string above is used.
function Get-HPECOMTelemetryConnectionString {
    if ($env:HPE_COM_TELEMETRY_CONNECTION_STRING) { return $env:HPE_COM_TELEMETRY_CONNECTION_STRING }
    $script:HPECOMTelemetryConnectionString
}

# Returns a genuinely anonymous, stable per-install identifier for telemetry.
#
# The id is a random GUID (first 16 hex chars) generated ONCE per installation and persisted to a
# local marker file in the user profile (~/.config/HPECOMCmdlets/install-id). It is NOT derived from
# the machine name, user name, MAC address, or any other identifying attribute, so it cannot be
# reversed or re-computed to point back to a person or device — it is an opaque, anonymous token used
# only to count distinct installs with dcount(anon_id). Deleting the marker file (or reinstalling)
# simply produces a new, unrelated id. If the file cannot be read or written (restricted/read-only
# profile), a fresh random id is returned for the current session only.
function Get-HPECOMTelemetryInstallId {
    $installIdPath = Join-Path $HOME '.config' 'HPECOMCmdlets' 'install-id'
    try {
        if (Test-Path $installIdPath) {
            $existing = (Get-Content -Path $installIdPath -Raw -ErrorAction Stop).Trim()
            if ($existing -match '^[0-9a-f]{16}$') { return $existing }
        }
        $newId = [System.Guid]::NewGuid().ToString('N').Substring(0, 16).ToLower()
        $null = New-Item -Path (Split-Path $installIdPath) -ItemType Directory -Force -ErrorAction Stop
        Set-Content -Path $installIdPath -Value $newId -NoNewline -ErrorAction Stop
        return $newId
    }
    catch {
        # Restricted or read-only profile: fall back to a session-only random id (not persisted).
        return [System.Guid]::NewGuid().ToString('N').Substring(0, 16).ToLower()
    }
}

#EndRegion


#Region ---------------------------- GLP PATHS -------------------------------------------------------------------------------------------------------------------------------------------


[uri]$ccsSettingsUrl = 'https://common.cloud.hpe.com/settings.json'
function Get-ccsSettingsUrl { $script:ccsSettingsUrl }

[uri]$AuthRedirecturi = 'https://auth.hpe.com/profile/login/callback'
function Get-AuthRedirecturi { if ($Global:HPEGLoktaURL) { "$Global:HPEGLoktaURL/profile/login/callback" } else { $script:AuthRedirecturi } }

function Get-SchemaMetadataURI { "$(Get-HPEOnepassbaseURL)/v2-get-user-schema-metadata" }

[String]$OpenidConfiguration = '/.well-known/openid-configuration'
function Get-OpenidConfiguration { $script:OpenidConfiguration }

function Get-SessionLoadAccountUri { "$(Get-HPEGLUIbaseURL)/authn/v1/session/load-account/" }

[String]$AuthnUri = '/api/v1/authn'
function Get-AuthnUri { $script:AuthnUri }

function Get-AuthnSessionUri { "$(Get-HPEGLUIbaseURL)/authn/v1/session" }

function Get-AuthnEndSessionUri { "$(Get-HPEGLUIbaseURL)/authn/v1/session/end-session" }

function Get-AuthnSAMLSSOUri { "$(Get-HPEGLUIbaseURL)/authn/v1/saml/config" }

function Get-AuthnSAMLSSOMetadataUri { "$(Get-HPEGLUIbaseURL)/authn/v1/saml/sp-metadata/" }

function Get-SAMLAttributesUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/um/saml?domain=" }

function Get-SAMLValidateDomainUri { "$(Get-HPEGLUIbaseURL)/authn/v1/saml/validate_domain?domain=" }

function Get-SAMLValidateMetadataUri { "$(Get-HPEGLUIbaseURL)/authn/v1/saml/metadata/manual/" }

function Get-AuthnSAMLSSOConfigUri { "$(Get-HPEGLUIbaseURL)/authn/v1/saml/async/config" }

function Get-AuthnSAMLSSOConfigTaskTrackerUri { "$(Get-HPEGLUIbaseURL)/authn/v1/async-task-tracker/" }

function Get-AccountSAMLNotifyUsersUri { "$(Get-HPEGLUIbaseURL)/accounts/ui/v1/customer/saml/notify/" }

function Get-AuditLogsUri { "$(Get-HPEGLAPIbaseURL)/audit-log/v1/logs" }

function Get-NewWorkspaceUri { "$(Get-HPEGLUIbaseURL)/accounts/ui/v1/customer/signup" }

function Get-WorkspacesListUri { "$(Get-HPEGLUIbaseURL)/accounts/ui/v1/customer/list-accounts" }

function Get-CurrentWorkspaceUri { "$(Get-HPEGLUIbaseURL)/accounts/ui/v1/customer/profile/contact" }

function Get-MyUISessionUri { "$(Get-HPEGLAPIOrgbaseURL)/internal-sessions/v1alpha1/my-ui-session" }

function Get-Workspacev1Uri { "$(Get-HPEGLAPIbaseURL)/workspaces/v1/workspaces" }

function Get-Workspacev2Uri { "$(Get-HPEGLAPIOrgbaseURL)/organizations/v2alpha1/workspaces" }

function Get-WorkspaceMigrationUri { "$(Get-HPEGLAPIOrgbaseURL)/internal-identity/v2alpha1/workspaces/" }

function Get-DomainUri { "$(Get-HPEGLAPIOrgbaseURL)/identity/v1alpha1/domain-requests" }

function Get-DomainDeleteUri { "$(Get-HPEGLAPIOrgbaseURL)/identity/v1alpha1/domains" }

function Get-SSOConnectionUri { "$(Get-HPEGLAPIOrgbaseURL)/identity/v2alpha1/sso-profiles" }

function Get-IdPValidateMetadataUrlUri { "$(Get-HPEGLAPIOrgbaseURL)/identity/v1alpha1/sso-profiles/idp-url" }

function Get-IdPValidateMetadataFileUri { "$(Get-HPEGLAPIOrgbaseURL)/identity/v1alpha1/sso-profiles/metadata" }

function Get-AuthenticationPolicyUri { "$(Get-HPEGLAPIOrgbaseURL)/identity/v1alpha1/sso-authentication-policies" }

function Get-UsersUri { "$(Get-HPEGLAPIOrgbaseURL)/identity/v2beta1/scim/v2/Users" }

function Get-UsersWithAuthSourceUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v2/um/users" }

function Get-UserTenantWorkspaceMembershipUri { "$(Get-HPEGLAPIOrgbaseURL)/organizations/v2alpha1/workspaces" }

function Get-WorkspaceUsersUri { "$(Get-HPEGLAPIOrgbaseURL)/workspaces/v2alpha1/workspaces" }

function Get-UsersRolesUri { "$(Get-HPEGLAPIOrgbaseURL)/internal-platform-tenant-ui/v2/roles" }

function Get-AuthzUsersRolesUri { "$(Get-HPEGLUIbaseURL)/authorization/ui/v2/customers/users/" }

function Get-RoleAssignmentsUri { "$(Get-HPEGLAPIOrgbaseURL)/internal-platform-tenant-ui/v2alpha2/role-assignments" }

function Get-AuthorizationRoleAssignmentsV2Alpha2Uri { "$(Get-HPEGLAPIOrgbaseURL)/authorization/v2alpha2/role-assignments" }

function Get-ScimUserGroupsUri { "$(Get-HPEGLAPIOrgbaseURL)/identity/v2beta1/scim/v2/extensions/Users" }

function Get-CreateUserUri { "$(Get-HPEGLAPIOrgbaseURL)/internal-platform-tenant-ui/v2alpha2/users" }

function Get-InviteUserUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/um/invite-user" }

function Get-ReInviteUserUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/um/resend-invite" }

function Get-UserPreferencesUri { "$(Get-HPEGLUIbaseURL)/user-prefs/v1alpha1/preferences" }

function Get-SaveUserPreferencesUri { "$(Get-HPEGLUIbaseURL)/user-prefs/v1alpha1/save-preferences" }

function Get-DevicesUri { "$(Get-HPEGLAPIbaseURL)/devices/v1/devices" }

function Get-DevicesUIDoorwayUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/devices" }

function Get-DevicesAddUri { "$(Get-HPEGLAPIbaseURL)/devices/v1/devices" }

function Get-DevicesStatsUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/devices/stats" }

function Get-DevicesApplicationInstanceUri { "$(Get-HPEGLAPIbaseURL)/devices/v1/devices" }

function Get-DevicesATagsUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/devices/tags" }

function Get-RemoveDevicesUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/devices/unclaim" }

function Get-DevicesLocationUri { "$(Get-HPEGLAPIbaseURL)/locations/v1/locations" }

function Get-LocationsTagsUri { "$(Get-HPEGLAPIbaseURL)/locations/v1/locations/tags" }

function Get-SubscriptionsUri { "$(Get-HPEGLAPIbaseURL)/subscriptions/v1/subscriptions" }

function Get-LicenseDevicesUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/license/devices" }

function Get-AddLicenseDevicesUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/customers/license" }

function Get-RemoveLicensesUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/license/unclaim" }

function Get-PreclaimLicenseUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/license" }

function Get-LicenseDevicesProductTypeDeviceUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/license?product_type=DEVICE" }

function Get-ServiceSubscriptionsListUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/license/service-subscriptions" }

function Get-AutoSubscriptionSettingsUri { "$(Get-HPEGLAPIbaseURL)/subscriptions/v1/auto-subscription-settings" }

function Get-AutoReassignmentSettingsUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/license/auto-renewal" }

function Get-ApplicationsProvisionsUri { "$(Get-HPEGLUIbaseURL)/ui-doorway/ui/v1/applications/provisions" }

function Get-RegionsUri { "$(Get-HPEGLUIbaseURL)/geo/ui/v1/regions" }

# Used by deprecated Get-HPEGLServiceResourceRestrictionPolicy function (legacy RRP endpoint)
function Get-AuthorizationResourceRestrictionsUri { "$(Get-HPEGLUIbaseURL)/authorization/ui/v1/resource_restrictions" }
function Get-InternalAuthorizationResourcesUri { "$(Get-HPEGLAPIOrgbaseURL)/internal-authorization/v2alpha1/resources" }

function Get-ScopeGroupsUri { "$(Get-HPEGLAPIOrgbaseURL)/authorization/v2alpha1/scope-groups" }

function Get-ApplicationsLoginUrlUri { "$(Get-HPEGLUIbaseURL)/authn/v1/onboarding/login-url/" }

[String]$ApplicationsAPICredentialsUri = $HPEGLUIbaseURL + '/authn/v1/token-management/credentials'
function Get-ApplicationsAPICredentialsUri {
    if ($Global:HPEGLUserApiBaseURL) {
        "$Global:HPEGLUserApiBaseURL/authn/v1/token-management/credentials"
    }
    else {
        $script:ApplicationsAPICredentialsUri
    }
}

# Legacy RRP URI - Not currently used (reserved for backward compatibility)
function Get-ResourceRestrictionsPolicyUsersUri { "$(Get-HPEGLUIbaseURL)/authorization/ui/v2/resource_restriction/" }

function Get-AuthZApplicationsUri { "$(Get-HPEGLUIbaseURL)/authorization/ui/v1/applications/" }

# [DEPRECATED] Legacy Resource Restriction Policy (RRP) API endpoints
# HPE GreenLake has replaced RRP with Scope-Based Access Control (SBAC)
# These constants are maintained for backward compatibility with deprecated functions
# Use Get-HPEGLServiceScopeFilter and scope group functions instead
function Get-ResourceRestrictionPolicyUri { "$(Get-HPEGLUIbaseURL)/authorization/ui/v1/resource_restriction/" }

function Get-SetResourceRestrictionPolicyUri { "$(Get-HPEGLUIbaseURL)/authorization/ui/v1/customers/applications" }

function Get-DeleteResourceRestrictionPolicyUri { "$(Get-HPEGLUIbaseURL)/authorization/ui/v1/resource_restriction/delete" }

function Get-ApplicationInstancesUri { "$(Get-HPEGLUIbaseURL)/authorization/ui/v1/application_instances" }

function Get-ApplicationProvisioningUri { "$(Get-HPEGLUIbaseURL)/app-provision/ui/v1/provisions" }

function Get-ServiceManagersUri { "$(Get-HPEGLAPIbaseURL)/service-catalog/v1beta1/service-managers" }

function Get-OrganizationsListUri { "$(Get-HPEGLAPIOrgbaseURL)/organizations/v2alpha1/organizations" }

function Get-OrganizationsUsersListUri { "$(Get-HPEGLAPIOrgbaseURL)/identity/v2beta1/scim/v2/Users" }

function Get-OrganizationsUsersGroupsListUri { "$(Get-HPEGLAPIOrgbaseURL)/identity/v2beta1/scim/v2/Groups" }



#EndRegion


#Region ---------------------------- VARIABLES -------------------------------------------------------------------------------------------------------------------------------------------

[string]$APIClientCredentialTemplateName = 'COM_PS_Library_Temp_Credential'
function Get-APIClientCredentialTemplateName { $script:APIClientCredentialTemplateName }

#EndRegion


# No Export-ModuleMember to keep functions private
# SIG # Begin signature block
# MIIn2wYJKoZIhvcNAQcCoIInzDCCJ8gCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDYWbaRPKquQTP7
# LQKaWwWzgERq1AOEs2Wt3tloqfKQwqCCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
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
# A+rbZZyGZkz3xbUYKTGCGq4wghqqAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMgQ29k
# ZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUDBAIB
# BQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# 00oGd5OYZCUXWdKD3B7Ela9HNMIplY2e6TBb93kbyHkwDQYJKoZIhvcNAQEBBQAE
# ggIAiJMilHkj1iPpK9FkcZ189/LFH1xupBG7bmQ18A3J1ttfCykCZBjr3Uj4xCTB
# Jt7F7xuDX8fFrKbqfXS0Wfapzi230NsLha0+8E4HV4rC9iN48w9zHX8mGR6CpNAg
# jTeIF3N0Do6zqiqQLjRLYLHw8KFgaTlE1UfMZkTqQqWk07gfP0sMTUtIEcOnPyQP
# YlmV9xoypBHrGPedSafNUfJzXSlp5TXPU32tJLKhELpJ74lrlDz7vQDpy8pBVex4
# nuLHLCVe05yz37msBHnpy3sbBzIYmSiVCwSPvudItZAfqu+Xv7+jUTHv6PBSUXFM
# 9nzvtsmiQHCbxlDC1KCzt8u41RkFCEhJFVeBKls8KyLBzOFuckZIGILrhnUUxhuh
# +ZxUD5jPTqeFfbJtxb/1u8Lb7wvA5ecvkB17sy5V0lmExAb9fiblTLTliCOLoBri
# o4gIWCOiFnAJvF0zxEQo7xjxESRscMvez+CgwlCs3q3p1GgiCDA5Oh4aybIqGbEV
# t1yPdpNTPBsvKoYp1QUttGeGe+N4RCSZIGCOBNheVlOJhL9HkP0kIP5mCxrGZWPN
# M1tyzXUiLKoBN59yNPjdr/EGNttaV8pixmVy1iNruJNe3SBPtEtWSijN3NzqAdi/
# 2H0BG7/0khNqV2GE5yBMmLNGDlO/pjl9teR4urNmiTynx7ShgheYMIIXlAYKKwYB
# BAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEwDQYJ
# YIZIAWUDBAICBQAEMJbysLsMczG42FGnsahn/aKYsMBBV6QLEpUax6EUGbmzVOeL
# l956xYRjNHStnuwYyAIRAL/72Uaz/5WkQeslEmrFQz4YDzIwMjYxMTA0MDgyMTM4
# WqCCEzowggbtMIIE1aADAgECAhAOHrsyK1yKdT4SPyHO0PLZMA0GCSqGSIb3DQEB
# DAUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8G
# A1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBT
# SEEyNTYgMjAyNSBDQTEwHhcNMjYwODA1MDAwMDAwWhcNMzcxMTA0MjM1OTU5WjBj
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMT
# MkRpZ2lDZXJ0IFNIQTM4NCBSU0E0MDk2IFRpbWVzdGFtcCBSZXNwb25kZXIgMjAy
# NiAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxs29k1Tm4JzaUbG7
# JguLFMReom4s+59qCkx6qSHA6RS7nuwbD5Qz4y8ZadGvKnui6kXmZ3g9hVF9H6Vo
# N0BbHLBQ7Qs+CWSdmHqYaWNHOdCzNClMFEFTV8AybOTCPE/xxUuNW0nnyyylklWP
# 6fmUzeitJj7LaDqcZa1n5SKyCqr+wwyEuAWC92E+9aKmM9ZH26cOk3jlc6Jdu6S3
# 8z8x37qD+p15GmR8/t7W7ux2qIssqm7jazSbupnVD8j5lD6cyCrnYtGHuou7bH3c
# 59FbRSMOoL0sDZz01J87b1q76Q/K6jUuKu7UCl7gQbjJUmLaGuI/5NhUZO8VpZDK
# ulpyHjV25hYxsWDMK5OT2Us6MHFj5vdBJSnd0fhXeqq6AVBp8y4aoDbYYPrEYnTd
# TlG+7h9WcXI0yMHUPteIZxqTJgwx3ZkzL2kmd6eQvnm6IKwp/sQ1d+TeMIoJ/wMp
# 7f/9WnChuzENvW5j4LUFkYVzNrjlXIgsgxE3RQnRobStayuM2BNp/PgsLPDwJ7AQ
# iuSCkYL5ikuCzqtwk+DlO0znAkHEflxU77rvjetcC6k6Chvc+PLixXNIeSPR8BJA
# hLO9REVLzlyI0VqiWiPSvBuAdLD4uelqJQV520azq+BjFfcNknHtQcmMYORqPSeB
# OFlkW9pMDvmnJR2Wxl5xps4nQUsCAwEAAaOCAZUwggGRMAwGA1UdEwEB/wQCMAAw
# HQYDVR0OBBYEFItvUpXVe5ErYgmfWkEHh1ALIYySMB8GA1UdIwQYMBaAFO9vU0rp
# 5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQEAwIHgDAWBgNVHSUBAf8EDDAKBggr
# BgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUwJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcwAoZRaHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNI
# QTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQwOTZT
# SEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1s
# BwEwDQYJKoZIhvcNAQEMBQADggIBACC0vXEC9hZ5PZUAUQc/KivNH8O14Lxm+aeo
# c3T49xrKkw1+0/4kURRUckQECHNW5AMx6vAvmRcLAxQhPCkFoklPXxTNVhq+ocyI
# dTty6p3DHlPoXhWOORdfCH9WHFPSTpkVEcuEna/rOq5MGHd/B8b8tW9VyMBOYK6o
# yM3w/ZOpPOzOJd6uLsEg8AKPh04h6VBwqsxcUhRwy6igtAOpxkC9Z71A4cbJU0Vz
# +4Z143C80QIbErFdOhvbx/rgvS/0c9XmZg50Q3DATk1YY2UJyNv/PDOGZ6phyjRu
# snKbvdfKwXReK1GoYNxyObiXmLSKumcP29O0QgBP3Hjt4h/eDqhmJ4BgFYUsuuqi
# P6zhy0Kvk/1DXS3s+Cwb8zE7Gy73c9Y86y7biFQKiQtbEvZNbX/3B7UUbUrkimyZ
# crndmssumsdwmVR4uQK6WJUbd/5iK2LvgYpMzrF3jLV7+LQ6wlmP8pgXRGWT89Dm
# QnJyHWFydmpPMuOowEvh0DmNZgBtJKB3fS6zuxr4TlbyDLTqYH6RO/+0G+WnzDIe
# HwMsdtphazYRWh/9S7DbMgUei0q7UWZ5vSvSaNNdz41pGVgSGTtPaJQVOpv2bleG
# wEUW0h8sy/WJQ+BnBMvZoGavXYJY+x8iJL3pj7hBXvLZxwOk0itFgZLEkUM+eAH0
# fJERQFwgMIIGtDCCBJygAwIBAgIQDcesVwX/IZkuQEMiDDpJhjANBgkqhkiG9w0B
# AQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVk
# IFJvb3QgRzQwHhcNMjUwNTA3MDAwMDAwWhcNMzgwMTE0MjM1OTU5WjBpMQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lD
# ZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUg
# Q0ExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtHgx0wqYQXK+PEbA
# HKx126NGaHS0URedTa2NDZS1mZaDLFTtQ2oRjzUXMmxCqvkbsDpz4aH+qbxeLho8
# I6jY3xL1IusLopuW2qftJYJaDNs1+JH7Z+QdSKWM06qchUP+AbdJgMQB3h2DZ0Ma
# l5kYp77jYMVQXSZH++0trj6Ao+xh/AS7sQRuQL37QXbDhAktVJMQbzIBHYJBYgzW
# Ijk8eDrYhXDEpKk7RdoX0M980EpLtlrNyHw0Xm+nt5pnYJU3Gmq6bNMI1I7Gb5IB
# ZK4ivbVCiZv7PNBYqHEpNVWC2ZQ8BbfnFRQVESYOszFI2Wv82wnJRfN20VRS3hpL
# gIR4hjzL0hpoYGk81coWJ+KdPvMvaB0WkE/2qHxJ0ucS638ZxqU14lDnki7CcoKC
# z6eum5A19WZQHkqUJfdkDjHkccpL6uoG8pbF0LJAQQZxst7VvwDDjAmSFTUms+wV
# /FbWBqi7fTJnjq3hj0XbQcd8hjj/q8d6ylgxCZSKi17yVp2NL+cnT6Toy+rN+nM8
# M7LnLqCrO2JP3oW//1sfuZDKiDEb1AQ8es9Xr/u6bDTnYCTKIsDq1BtmXUqEG1Nq
# zJKS4kOmxkYp2WyODi7vQTCBZtVFJfVZ3j7OgWmnhFr4yUozZtqgPrHRVHhGNKlY
# zyjlroPxul+bgIspzOwbtmsgY1MCAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwHQYDVR0OBBYEFO9vU0rp5AZ8esrikFb2L9RJ7MtOMB8GA1UdIwQYMBaA
# FOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAK
# BggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4
# oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJv
# b3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqG
# SIb3DQEBCwUAA4ICAQAXzvsWgBz+Bz0RdnEwvb4LyLU0pn/N0IfFiBowf0/Dm1wG
# c/Do7oVMY2mhXZXjDNJQa8j00DNqhCT3t+s8G0iP5kvN2n7Jd2E4/iEIUBO41P5F
# 448rSYJ59Ib61eoalhnd6ywFLerycvZTAz40y8S4F3/a+Z1jEMK/DMm/axFSgoR8
# n6c3nuZB9BfBwAQYK9FHaoq2e26MHvVY9gCDA/JYsq7pGdogP8HRtrYfctSLANEB
# fHU16r3J05qX3kId+ZOczgj5kjatVB+NdADVZKON/gnZruMvNYY2o1f4MXRJDMdT
# SlOLh0HCn2cQLwQCqjFbqrXuvTPSegOOzr4EWj7PtspIHBldNE2K9i697cvaiIo2
# p61Ed2p8xMJb82Yosn0z4y25xUbI7GIN/TpVfHIqQ6Ku/qjTY6hc3hsXMrS+U0yy
# +GWqAXam4ToWd2UQ1KYT70kZjE4YtL8Pbzg0c1ugMZyZZd/BdHLiRu7hAWE6bTEm
# 4XYRkA6Tl4KSFLFk43esaUeqGkH/wyW4N7OigizwJWeukcyIPbAvjSabnf7+Pu0V
# rFgoiovRDiyx3zEdmcif/sYQsfch28bZeUz2rtY/9TCA6TD8dC3JE3rYkrhLULy7
# Dc90G6e8BlqmyIjlgp2+VqsS9/wQD7yFylIz0scmbKvFoW2jNrbM1pD2T7m3XDCC
# BY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290
# IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE9
# 8orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9S
# H8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g
# 1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RY
# jgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgD
# EI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNA
# vwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDg
# ohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQA
# zH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOk
# GLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHF
# ynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gd
# LfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE
# FOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNy
# dDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkq
# hkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7
# IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/5
# 9PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0
# POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISf
# b8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhU
# LSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDGCA4wwggOIAgEBMH0waTEL
# MAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhE
# aWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAy
# MDI1IENBMQIQDh67MitcinU+Ej8hztDy2TANBglghkgBZQMEAgIFAKCB4TAaBgkq
# hkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MTEwNDA4
# MjEzOFowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQU6ainI7SFBPXg4UOLZz7Oh88s
# UJswNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgcR3XexwucbJh11WNaZwAd8l9EgMw
# mmCO3BBWNMFQUHswPwYJKoZIhvcNAQkEMTIEMBtZt1iXGG/4HBZjLwEHmLeBTSYD
# mk5i0Yf2KRcYdrgCWvSV/aJxPmJYAu3CuHTB3DANBgkqhkiG9w0BAQEFAASCAgBJ
# 4E4wVDk+RFyg5yqibG6XH2Xwoh/uM4uUQjaRiCp67iO7TuXK68xra5147HKZjlea
# KOna+MBBmhRZDpug9R+v/1VhJZu8ocRAxUNJq1GNZDcS6iQCl5V/JUVL5qtUp+U9
# Y2AXjISX3sByjLVKL+0PN/seAnQKLOhLANQomexvhNQ7/dNgxFqa1shu6Wd3auX/
# MazWdNB6Wm7hm7RyIe4wgn7PBmGcNLvyv/6E5YnBMXwblB/b4RVCszt+4qYm0I8f
# P+XP+R2PeqtQglSb7XCpvF803M8mxWiAqG5pqdGxW9gtk9iO13A8S94utIB2jh5n
# 1P+fWms2kRYEIy3PNyzi7Rmd0YnsqNtN3S5zGM+m0bep7ibSUhnAyZoQzJEX33Os
# 8BIwXWWaZxUnY9JCpDVK6QHuKBLOj+iRHyNMJ23DbwNDi9e2wyDvqnBrxQOgfMdC
# QtTag71XSKUj/QNcUKTDsAY1WSzewyhSpPxYSdCD0Pr5cNd73A3jW7APw3fVVgwW
# 4r2Q4uHXBliepkWB2sRysqqsGW/IDChGFAPT1of5S4ZljW6/2/D9CYR1cMku4g/T
# aoKuJoeHtWw0Bm2Yf2hoD2GiA1dCDLFhQOxFcdddykoYDNjPVWdmvL47ckujAGt5
# K83UocFmWR+fUxureHzXhaBpoIEXQ4PX+a9P9hvJnw==
# SIG # End signature block
