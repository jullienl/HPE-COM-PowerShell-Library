
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

function Get-ScimUserGroupsUri { "$(Get-HPEGLAPIOrgbaseURL)/identity/v2alpha1/scim/v2/extensions/Users" }

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
# MIIvswYJKoZIhvcNAQcCoIIvpDCCL6ACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAGvuk0YZKdZUz2
# Rad4/Vd8ENMg0KJBld+6LryJPqrTr6CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# nZ+oA+rbZZyGZkz3xbUYKTGCHRMwgh0PAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQgkc/0OBYhsD8cIfQRQRS2PhvelSCSSUvapFvo+WySLc0wDQYJKoZIhvcNAQEB
# BQAEggIAOJLc1kcYGb+Ht87ckMQS2pEvaXW35PWEtv0MThxs3sCTsOoXCO1tojo4
# 0kbVqpiKYNXou1rZV8MYY20No1DQs/K44zznEQA/2R/GtAHQtEZGA/6u0i4G+qqH
# QgWDd0QEoJnF5cnt+0ldIxW0Bt99oMJfJ0fKu1U4H/BXTKzj0mStm5TQfJxPRzfs
# DKD4ve91z/tI5vqwT3Bcz5Ui3H0tD0nkS03GfeVE6FSi44+EgUp/66+KOQcjlauY
# 0iKbKMgbQpaVJQVxLT2+CqmxKR+NVoFxqauqrJ1njBZgMpM4SGYTUniLSBWQ73KZ
# IbkUkrUbwqZQSwh2DOkTzvPlN0tGCiX8iYBwJlVvnLvOys0dffwVqOcfms/HMdXp
# RDTc6QqeOsaOdUlzTwc4zo0hlMzq/FlP8H4zNgtr/bJX7qznn4b1B83iqIhmn+WP
# ZfkeVfhNt07j8DwOmT1XYJTzSfOwowKfNPY78D/keMp5Mr4iY9iFPQ2Li7jNah78
# qTQSF3y//QhbaDyi2u3i+pKTk+11XKQtQiQou8B9qm+mU3JxFItZf3iHkHYHrC5O
# wmJGq9/tUstBGluvg7zdqScVWbctwAhnK2xDi6lRa3DCngkBTe5Sqq60/c0yktOt
# 5yYJqF0r6VdpkoWGF4fNPmGgIF0m4tkp9VyS4+BLHim8kHV/jPShghn9MIIZ+QYK
# KwYBBAGCNwMDATGCGekwghnlBgkqhkiG9w0BBwKgghnWMIIZ0gIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwYPAdyxkz9gCZGbg/IYcfWePLpm+7+ry1eUhq
# LvLDBQnfgvEUmwYXvLEU+zOopS0xAhUA6W1v94MKTy7MXjM/ddyobdT8YMsYDzIw
# MjYwNjI2MTM0NTU5WqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDkdyZWF0
# ZXIgTG9uZG9uMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMTJ1Nl
# Y3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgU2lnbmVyIFIzN6CCFBcwggbiMIIE
# yqADAgECAhEA507yVbBQT/rbpt/3/IujFTANBgkqhkiG9w0BAQwFADBVMQswCQYD
# VQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0
# aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFI0MTAeFw0yNjAzMjUwMDAwMDBa
# Fw0zNzA2MjQyMzU5NTlaMHIxCzAJBgNVBAYTAkdCMRcwFQYDVQQIEw5HcmVhdGVy
# IExvbmRvbjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTAwLgYDVQQDEydTZWN0
# aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFNpZ25lciBSMzcwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQCy/8NtS9xQ2UUtBRF32bj7VK3n4m50Uqjk/zTc
# iSziYV40H1LKah0/oEklYG42E4VCP3DvsBUB6DmpCkDZ0jCnZBPIEevaH15ZJOQw
# FWP2ZXr5YjlJpb68Nlbs+ElNvKx32/1YHde3qqUSLybjulxPLz6T85+HOIqK7M1B
# ep8LspyhEP/q6nw5kGxTSrGvufmeH+JF8CnVBcVMFA40FlIYh0cDJVFhhfTfdWgL
# y/vWuLMQoKkf3s/FvByf16r0rtbyHm/iemwxSioJL9zyZDDKUNAbHXl0dhXo2VxU
# V2NcPXWXuoKsjL+6cfk6Vm2DHnxAlFdFsaBDIF1JOkSnC6PeLlBznZn2buF3vIIY
# Jcq6N/zeFRCk4/HXDz7zgRsRRMdUB+rhyk5FoZaBjw0nLq3GZ3fClLUx5es5pUAx
# zNODMBn7JkFYip2BAGBPER5eV0ROhk6tGTG+fUiMiV+vgjg1YnP5FvnYWyEtWeQD
# /B2hp3vz0RvtdkM0p3igyadzrfpOBq5ppVk/YsuhTQkP99ivneHAGfi5e7lmxJ+m
# eoBPrRLuzMmb81rzzbESjJHMsn5RVtc6Ucs7rcMqQC13PUIO7BbGBETV2ufCmV6l
# PTp3P7XJOvmnUCRTPbVvMTpxP/z+SOHg4/OCBhiqs4FA9+4oQvlkk9w32NGASli9
# GWrm5wIDAQABo4IBjjCCAYowHwYDVR0jBBgwFoAUOnSlDGfGQlDC/bX8x7spNIL0
# erkwHQYDVR0OBBYEFGEQ6XoSr1HEhdTyz6R0D1DNIK/4MA4GA1UdDwEB/wQEAwIG
# wDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEoGA1UdIARD
# MEEwCAYGZ4EMAQQCMDUGDCsGAQQBsjEBAgEDCDAlMCMGCCsGAQUFBwIBFhdodHRw
# czovL3NlY3RpZ28uY29tL0NQUzBKBgNVHR8EQzBBMD+gPaA7hjlodHRwOi8vY3Js
# LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVI0MS5jcmww
# egYIKwYBBQUHAQEEbjBsMEUGCCsGAQUFBzAChjlodHRwOi8vY3J0LnNlY3RpZ28u
# Y29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVI0MS5jcnQwIwYIKwYBBQUH
# MAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4ICAQAD
# 6j2N0azN+hl6k6bKB5/U6VuSOs93ZBb3Pczy9VtBIKu4947Z5GwL0aFngIxl+GSu
# LFrJgPruBCRvKJEJsm7kv+LQ1COVCEG9tZ+IRtr4ocUoa53lgdFaENlS0N4wgkZk
# bQEPv+x+1lSjYh+T4JeL9mUznT7Erc6Sp5dWLka5sMP/m3GZi6oJPdPcsCKWagH7
# m2H2xDGIyHJC5PdH9phvi/KmhkktiSVTNNqVeV5bWdX2zhRE6UTfz0IcMoCL996l
# FIydXxOCE4MNDHDM0as4lnTiT/KHMccO6l8c9TnUVgmpci9ar1IABZ2U1XUkYjGG
# Sn9MC3EHDP9V39VuBVvZ33/BEV/EWSRrf07T7jFplKX+gQr/UOqPGMlE7ZJ72UaU
# kNJy7bVl3bcLKzdpjIHzLkf/4MVa1V7w8wqCv5W4gOnRGTlud5UMARbRM8BPxR/C
# XYXoMmIOD8pmTk2axgRL4LG8XtuchISdCHRmtacAmLGq5XSYSVTHTXADlO48iDKh
# 3HM2r98LSF6f0sG12d8V9Jn7C3wDUieOxuKj4MdWrW+hiJU2kF87v6eH00HgCFFc
# 2V0+CvfOCMn7juzS41jLaINcBlKWQ/fKb/uDLfWOW73z1I2lFY7Xj8tQ1XYtK5eR
# EjWItM8jpl1cbQOc88btR+0XS2TmboE/141+va2PWzCCBqcwggSPoAMCAQICEQCQ
# rAhyIP3Fp8RrXMcN9z0GMA0GCSqGSIb3DQEBDAUAMFcxCzAJBgNVBAYTAkdCMRgw
# FgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGlj
# IFRpbWUgU3RhbXBpbmcgUm9vdCBSNDYwHhcNMjYwMzI1MDAwMDAwWhcNNDEwMzI0
# MjM1OTU5WjBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFI0MTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK7kSqIBrYIcYvlmLVuaA8zw
# 1RfBhkn4G1CoemzjcYtML6yNUvKmwGH7y6/5MuSC1UYP/+9KYDSqvMQt/1hEKHYx
# MAD9oZpBkoaDQFEKbOJHelsKe+BaO0ZcENTKfePcraVkA7wrGAW2XHA5gQCQv4IK
# ori/3PNOXxnDMOk8yIMgVrlMeTxqfWJ4XkjT1xc2s9DD7URHWWJOFobTPoWs6mrD
# FlaY9FlAHDYTfbzvxQHVsvRmn3W+5ZmCwyk02I8KgGPT/UX4sTz41GiR+ppwUjQX
# a1+2tEHZbsdAKUtH3OPEVtZvlt7atx4h83IdRR8oYi8wjY3OjFKXFecWpQbzzsPx
# bUKPwMWiTrzwkrFa8dH/1pDKRJt371W62PfqKPayCr/XbnBOlRn8CALSmHnRtGzu
# AWtTJpcT3BKw6oy8IIL6wSbu938F6ZIbRNIc1dKbIJtr4ULN6R5ZfTdNEhwXctqp
# 3RHDbg4fuOl6LjNoaFwjud92EEDhzxFJzE1jqN4csceZIwxOT1aqfsfh0uFQE/lg
# TBuBs3i6/WL2W1OceWLy3XEdXRK1f0EWCuea6dNfX2RRdjUfk5EltFnJkN2+bWhn
# K14OPRKcyjOv5hKZ0iV4NRNd1+hjtva1rPyzb5Bs7EvFxqEQhgZbOq7qH3nm0rBw
# A0dxniBOYCFPdu246JCxAgMBAAGjggFuMIIBajAfBgNVHSMEGDAWgBT2d2rdP/0B
# E/8WoWyCAi/QCj0UJTAdBgNVHQ4EFgQUOnSlDGfGQlDC/bX8x7spNIL0erkwDgYD
# VR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYB
# BQUHAwgwIwYDVR0gBBwwGjAIBgZngQwBBAIwDgYMKwYBBAGyMQECAQMIMEwGA1Ud
# HwRFMEMwQaA/oD2GO2h0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1Ymxp
# Y1RpbWVTdGFtcGluZ1Jvb3RSNDYuY3JsMHwGCCsGAQUFBwEBBHAwbjBHBggrBgEF
# BQcwAoY7aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0
# YW1waW5nUm9vdFI0Ni5wN2MwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3Rp
# Z28uY29tMA0GCSqGSIb3DQEBDAUAA4ICAQAy3lJHZvGeA2b43yhzoarvobHVzbfl
# +RfuPDwej0wCQkYAN6scTt2GwFe22qbOCv/tllqFlLKQZE+E9jVyuPTbyQHwrM7R
# 0oLapAEDC1+CowsqSRf/ptira5Pfd4PoHICnb9coPQtyZmHSQp5y9IGvqWf1qNfq
# 7V2fHZ8DvEQrLUzeoGF9BJRYu2OzacW3QQtUum3NOVf0gPRwv6I4991uhncJ6VP4
# lcpUpHZKB7R3hiIUC09mR9KjzPVnXHvL9n2bAwiUECfK5Zezhiw27F2tgi39DETf
# U8M4n0N6xLgFzsf05M5GURX8C9+IX9V6kpmmKtrUzMti4LD66gtmf+mSm934K81N
# L6YQeMEk1rpYrWPypcW76Mir6wb1AgseLIHqn/GkeuQm7zOTDf3f5WoX14qVNjZW
# NHF3JxkutV6ZnhinfCLfdv5bnwKWUfceqOajCVntI6uCbHxjBg6SCsexc5AfIGno
# 7gVFvwifT4XONPsSUaJ71XsJ+EvciVUVnjOO4qxm0fWJTd8a7jP8mc4ZPqwJvQFt
# Op7+6G+kUJAF0fnE8YgD8uttBReNTa1YmAeFMiqc38e8fI4eLm0zjM/eeGCHasno
# qqrbGwcF41iz9HXzFDwN4iD5z3QShp6HRiU3UpTwDJiiXcr0z6pjl7PyzJ3/tmWt
# GehV7CAfc/WlyzCCBoIwggRqoAMCAQICEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZI
# hvcNAQEMBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQw
# EgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3
# b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9y
# aXR5MB4XDTIxMDMyMjAwMDAwMFoXDTM4MDExODIzNTk1OVowVzELMAkGA1UEBhMC
# R0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQ
# dWJsaWMgVGltZSBTdGFtcGluZyBSb290IFI0NjCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAIid2LlFZ50d3ei5JoGaVFTAfEkFm8xaFQ/ZlBBEtEFAgXcU
# manU5HYsyAhTXiDQkiUvpVdYqZ1uYoZEMgtHES1l1Cc6HaqZzEbOOp6YiTx63ywT
# on434aXVydmhx7Dx4IBrAou7hNGsKioIBPy5GMN7KmgYmuu4f92sKKjbxqohUSfj
# k1mJlAjthgF7Hjx4vvyVDQGsd5KarLW5d73E3ThobSkob2SL48LpUR/O627pDchx
# ll+bTSv1gASn/hp6IuHJorEu6EopoB1CNFp/+HpTXeNARXUmdRMKbnXWflq+/g36
# NJXB35ZvxQw6zid61qmrlD/IbKJA6COw/8lFSPQwBP1ityZdwuCysCKZ9ZjczMqb
# UcLFyq6KdOpuzVDR3ZUwxDKL1wCAxgL2Mpz7eZbrb/JWXiOcNzDpQsmwGQ6Stw8t
# TCqPumhLRPb7YkzM8/6NnWH3T9ClmcGSF22LEyJYNWCHrQqYubNeKolzqUbCqhSq
# mr/UdUeb49zYHr7ALL8bAJyPDmubNqMtuaobKASBqP84uhqcRY/pjnYd+V5/dcu9
# ieERjiRKKsxCG1t6tG9oj7liwPddXEcYGOUiWLm742st50jGwTzxbMpepmOP1mLn
# JskvZaN5e45NuzAHteORlsSuDt5t4BBRCJL+5EZnnw0ezntk9R8QJyAkL6/bAgMB
# AAGjggEWMIIBEjAfBgNVHSMEGDAWgBRTeb9aqitKz1SA4dibwJ3ysgNmyzAdBgNV
# HQ4EFgQU9ndq3T/9ARP/FqFsggIv0Ao9FCUwDgYDVR0PAQH/BAQDAgGGMA8GA1Ud
# EwEB/wQFMAMBAf8wEwYDVR0lBAwwCgYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRV
# HSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9V
# U0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDA1BggrBgEFBQcB
# AQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJ
# KoZIhvcNAQEMBQADggIBAA6+ZUHtaES45aHF1BGH5Lc7JYzrftrIF5Ht2PFDxKKF
# Oct/awAEWgHQMVHol9ZLSyd/pYMbaC0IZ+XBW9xhdkkmUV/KbUOiL7g98M/yzRyq
# UOZ1/IY7Ay0YbMniIibJrPcgFp73WDnRDKtVutShPSZQZAdtFwXnuiWl8eFARK3P
# mLqEm9UsVX+55DbVIz33Mbhba0HUTEYv3yJ1fwKGxPBsP/MgTECimh7eXomvMm0/
# GPxX2uhwCcs/YLxDnBdVVlxvDjHjO1cuwbOpkiJGHmLXXVNbsdXUC2xBrq9fLrfe
# 8IBsA4hopwsCj8hTuwKXJlSTrZcPRVSccP5i9U28gZ7OMzoJGlxZ5384OKm0r568
# Mo9TYrqzKeKZgFo0fj2/0iHbj55hc20jfxvK3mQi+H7xpbzxZOFGm/yVQkpo+ffv
# 5gdhp+hv1GDsvJOtJinJmgGbBFZIThbqI+MHvAmMmkfb3fTxmSkop2mSJL1Y2x/9
# 55S29Gu0gSJIkc3z30vU/iXrMpWx2tS7UVfVP+5tKuzGtgkP7d/doqDrLF1u6Ci3
# TpjAZdeLLlRQZm867eVeXED58LXd1Dk6UvaAhvmWYXoiLz4JA5gPBcz7J311uahx
# CweNxE+xxxR3kT0WKzASo5G/PyDez6NHdIUKBeE3jDPs2ACc6CkJ1Sji4PKWVT0/
# MYIEkzCCBI8CAQEwajBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBM
# aW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENB
# IFI0MQIRAOdO8lWwUE/626bf9/yLoxUwDQYJYIZIAWUDBAICBQCgggH6MBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYwNjI2MTM0
# NTU5WjA/BgkqhkiG9w0BCQQxMgQwxpYFRxgNr1njaFVdXzTxYtferfb1HtI44iMu
# rG3KoUmxB6RHP2s2slStRG/CMx/jMIIBewYLKoZIhvcNAQkQAgwxggFqMIIBZjCC
# AWIwFgQU6XgYqSjaFQqf4b+czHqruaAO7qwwgYgEFGXDKGlvfU5QLP0Dx8IGlxjK
# +/dPMHAwW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0
# ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgUm9vdCBS
# NDYCEQCQrAhyIP3Fp8RrXMcN9z0GMIG8BBSFPWMtk4KCYXzQkDXEkd6SwULaxzCB
# ozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDAS
# BgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdv
# cmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3Jp
# dHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAEggIAKAoCKEZ5Xnh3
# rDJwLHboCYdVu6KQvTEdVfg+KIrWVqIz8x90oDD1nuRoqiP0VPYmTwg7rP9PBMhm
# A9qUXHsYz93HBvHLbAd+xR4tUei7RPNqxfDhuhkIZLBuWqZzoBOAk+wiXFKNYOmF
# 3CMK254r6ABScDdGfRRGQ/BjLgbm1RnZfkEHxH5U4yxan6p1+mwrsSsM/xxWNFW5
# 0w7P9+LPRMCI5E7NCsz9k/0faEFN0SzGev54t4FiUoCSQ837EcYSgY7L0EpgpIri
# eMJYAaS3Kgl0OdoFPP+IlNEFy5iYm6fAk1tfY1cvahpp6cXbxHbKYxj2ff8l5kLS
# 29v/PqHeL4GZYWClIhWbBcje4v4MrAzabNkHMGSvbjbqLmQzrjwGAflqziKsHXJK
# 5elQZqXNDxVhDrDgicr51mq6MD+/GhGW0cFZk8PEiDBS36vGPf1R37NNObr82zjP
# HlT8PkU5IX5+cW6hS9eGIJmG6yaUqhBi+Snx7koTNcASBno8bzO+tl2hLWhADlti
# Ad23K5rWyXQuuAL1IhJAWeNtzP2wRWc2GQgaizUKJDxVN0zxHpxTeOgrQI0SIlwC
# p61zyejAKOuXsjTaKj95zC1jbbAmxO9Abs6b9M65I72GOxcVud+ZMDsVk7uGXoFB
# 1bvTcIsRR9sVNSKg0WgjpSrOCJwkahg=
# SIG # End signature block
