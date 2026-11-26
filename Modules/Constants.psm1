
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

[String]$COMFirmwareAnalysisOverviewUri = '/api/compute/v1/firmware-ca-reports/overview'
function Get-COMFirmwareAnalysisOverviewUri { $script:COMFirmwareAnalysisOverviewUri }

[String]$COMFirmwareAnalysisUIDoorwayUri = '/ui-doorway/compute/v2/firmware-analysis'
function Get-COMFirmwareAnalysisUIDoorwayUri { $script:COMFirmwareAnalysisUIDoorwayUri }

[String]$COMGroupsUri = '/compute-ops-mgmt/v1beta3/groups'
function Get-COMGroupsUri { $script:COMGroupsUri }

# Hardware verification endpoints (secure-devices, devices/{id}/baseline, baseline) are only exposed under v1beta1
[String]$COMGroupsHardwareVerificationUri = '/compute-ops-mgmt/v1beta1/groups'
function Get-COMGroupsHardwareVerificationUri { $script:COMGroupsHardwareVerificationUri }

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

function Get-AuthorizationRolesUri { "$(Get-HPEGLAPIOrgbaseURL)/authorization/v2alpha1/roles" }

function Get-PermissionsUri { "$(Get-HPEGLAPIOrgbaseURL)/internal-platform-tenant-ui/v2/permissions" }

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

function Get-PersonalAPIClientsUri { "$(Get-HPEGLAPIOrgbaseURL)/internal-identity/v1alpha1/personal-api-clients" }



#EndRegion


#Region ---------------------------- VARIABLES -------------------------------------------------------------------------------------------------------------------------------------------

[string]$APIClientCredentialTemplateName = 'COM_PS_Library_Temp_Credential'
function Get-APIClientCredentialTemplateName { $script:APIClientCredentialTemplateName }

#EndRegion


# No Export-ModuleMember to keep functions private
# SIG # Begin signature block
# MIIqQAYJKoZIhvcNAQcCoIIqMTCCKi0CAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD9sJZLHQlOB5UB
# N6HcGdSdahtPTmTJV/YmMrN/xzKr9aCCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
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
# J8EaZGKYb0FMujxqC9VcKgsGScfsa186+cJiMbHfkIIwDQYJKoZIhvcNAQEBBQAE
# ggIACFgyRIcdIsrw2vU3AmoY9PR3AUzKakiDFbgMLZd78BBu74vG1xwjyNd3jEes
# 7tmSpazLmHq//yydr1rdHN16CWtBydsFL8Ek+jUun3X2FME1UTr6Yd8DYurN3eol
# aG5S5ea6nAk2F6Cex7XWKQ8RECJVrk54YvHU2w95B0g2LGWYFA+QLrAtjRt/OmKP
# PoS/PrlN4YMYKrl5vJmM9STpWiiOyZ93RFi5JcBukPwZYw3jB/vnOc3zeIADyfEX
# O0r0uAV8rMttTL1rdBGX+wV2JhPeiw9S7UvZU9gOJ2i6W0vB0xnwq1JZWX8CJimt
# y+AZKUw6UEQEPNBj+Awe+8WrhcFl7yn/TrdqQbthjBjrWwGlhewRlp+CUYxF4jeO
# m9gr1d11Nd4q9/SqCvS15De25SnY63Qea8K1QGKgAVUzosH875+unoeFg+EFS3Z3
# HSmgQ9tRyVYHqQ0tEgQPlRS2pUX9z26rnTrT6wM71va63wF8+7vTLmFQJgx9gbbP
# GF4kQatNF1R6F5qs9sPNwdggI27z/ryQlzES+Gka59bUZSOltKnks4tvrEcP17Zf
# RH05SUueUmiO0JgjhFGlnhj6sQd1kp1XNifyCzsns8ru002iBzshnA6+QT1T0Gib
# seia3r7GxkwtRBS1kkFY1vFcgtZIeX1YXotXMMnE1CJ3hKGhghn9MIIZ+QYKKwYB
# BAGCNwMDATGCGekwghnlBgkqhkiG9w0BBwKgghnWMIIZ0gIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjECAQEw
# QTANBglghkgBZQMEAgIFAAQwLU/g5suGWWRh7UfE/Gl6kznIN7Vym0OWZY9eS1/O
# YwXCLtPpCjEEDEJDGLNt9zRPAhUA+1k7mhOirKDWgh7ISlapbsh1f3kYDzIwMjYx
# MTI2MTc1NDE3WqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDkdyZWF0ZXIg
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
# DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYxMTI2MTc1NDE3
# WjA/BgkqhkiG9w0BCQQxMgQwi1jAEqwfRX1moIlPRDxzK2Zb70+lV/fR4PG6kxQ1
# MVg1ROwsFYlqR9UbI01RkNqPMIIBewYLKoZIhvcNAQkQAgwxggFqMIIBZjCCAWIw
# FgQU6XgYqSjaFQqf4b+czHqruaAO7qwwgYgEFGXDKGlvfU5QLP0Dx8IGlxjK+/dP
# MHAwW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQx
# LjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgUm9vdCBSNDYC
# EQCQrAhyIP3Fp8RrXMcN9z0GMIG8BBSFPWMtk4KCYXzQkDXEkd6SwULaxzCBozCB
# jqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNV
# BAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsx
# LjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkC
# EDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAEggIAc+BAV6VhR6f7kjgg
# /qkDOwT5udYrUs9E0xJzQDqI621sBt8luzUX+KtikzIIKZtDY+IElyVSF/UGoBJP
# Ir+pF1gAeBJ6GrP3nfTTnFsUrOuFpZ/53Oh9+k7wUZTW0VyVvgUcuwHNJz39AFbF
# 1PxkeEyiuoqCHnyWKfcUzbfIgL/ai+2L7cbBNXEuTGbk6Tx+otUdSrUpokXXW4n8
# o3feyUn1rx5ZW3yYY5+JIw/QZrkC+F9s9gLdaAqbhFwsFxml+y83ax/qu3wn2ulP
# wptdPlhit9YGGOjRW169TsQMb996CkEMSAFGbnJusZAOlYhYJmMbq3gStP864IAR
# IrxJmgeQP3D+qy+DB89zw3n47tlpvFIpwJmwe3mC5ReeW9EI3hiPMFsIqNA63guB
# Y5qkZPoIg9BmOjgbl9JSOF79fLnTFcU6A9bsK6W6+vn7Zl3Q4riZC4emn0v56piL
# sBRYXwtQlQGvuU7fu0fgGraIz1vo6Aj1ww4DBSkW9PEGBiauLG3reaZxSeLFjWGo
# kr9x9EOmua4rEYGlx+1NIirQnWPWEyc46n4cTf6n3dj/6wfqwHDTwivYV07NbOmF
# TXHPzdO3Kq1B3C7tEzkEPlE9FMFFBCXO57m9oXM5ficnkvWmQMRuPx5rpMxB0QID
# vgQTZ8j6apuAzz5g68/hE6IBpeA=
# SIG # End signature block
