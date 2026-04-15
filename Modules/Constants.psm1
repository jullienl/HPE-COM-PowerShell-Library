
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
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCZxbMs/yZFP+Fn
# OD2JS6S/31E41sogh7+PE9zNgnAWbqCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgdaBiIHiQboc5hH09SLz6vvDgDl89Y/IXZSWIl+OmEdswDQYJKoZIhvcNAQEB
# BQAEggIAJygT/dukN8lgvHAfAXgGlpgIAoZhwTjNZldLYf64shu9DkH1qhJe2Yfs
# 74O0aB9Aetfp/O7ooyw22bVET9cVH3/tdzMAg0LwIqrlZ7B8/wTVLzCtkLG6v+cP
# mX2YZIR6XE7FX5ifp6KcI84sVzqP7BZljpdDlcfz65GUyLA+kNjeoJVzhiQRkvQL
# OpqY7piJ5u3kkGU1eNITIWj+lu9dRkJKHmhfHfWsi9ty1h0UI6Z6YGm8RtR5RF0Q
# We9KxoEjHx030hlU2AvG+IaEXfkcCQK+JImiCpvDDyrxKf1Ltk+JNTL+KdoN/VuI
# NbdXL8CJsoY/hIkBQ/KTbZE0s0EtdGmZtAiCh007Zp4jWsw8JvjCjJVN5y3qEBSQ
# L60x4KkufrIfU0WIqAv6wFh57Y1Zg5SVhFJqlAyU+P/ctacbJoWZnOA70OBoHX9u
# XgkRvYgulGuzlksWexi/6nHPgVe/3jUwLvIvWaKiMHZNgakwUs5bzI/J6crJIwkE
# c57Jpef9eS0foyw4qik73OsewHaq6LL5Rt+GZd85OkrosdjSi3J4Or2wC80fg0Oe
# Jlb7KLnlXsyv2WUa88w8KVQTVECjAbd0vXQkosmhDhgrJFE2JQj9ED2b6Uzn0tl1
# AfNhJfCgOSScN7gt26fiaivvcGN12fUfkAYtzGlwC5iIY/+TX6ChghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwtOTAWHcH/CztWuV47II0FQ1A0fJEojR97b10
# 4ZwTiooGZIBCh2MOnruwNygzr/9KAhQELeYUkd2bAxhoT+cOr57Y3ar81hgPMjAy
# NjA0MTUwOTE1MjFaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
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
# DxcNMjYwNDE1MDkxNTIxWjA/BgkqhkiG9w0BCQQxMgQwMFBKSwGia+qmhfr4tLzO
# jk4OCC6ur8q7eVWFNqJ2NhkWRkY146fNF29JvEevd2JRMIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgB+0WULSN2FNkhda70s/nLDaIzqFtbUA14K3+3vUUsIbNDGP6J4hupXjF2r+iHv
# X9O0FiLX+LxBw5/QsX3SehJ1t0m9456JigTMyPr9TxEnH7aGTdZgrAcc4hMQXnZn
# UApnVOr3hvdzEFn38Igbrb/6OWM3AlP4zYEpIx+LeGUtXFP4YAcpad5jjN6CRCDR
# d4Wolxd0HNDn0ZrFpqqoIKkUo7Jya55gzunu3s4qc3LISuYgV7W6aA8f4qmzTyTO
# YKeM+rf60090Ryg03QNgFfKM2foBsBBNFq8PDu0lVYOkfSQ1BuclIPLlDPCpGFCk
# vEQ7jiaaFB9lvFIReMVzp7/fyAxGuA5ufypSVe66q6WgKLckccYvPao/bs3yXV4j
# qSCrktM1MkEUB57czjRND4nHZy3sopacNLGvSWh3OUPJzUmsVY+U8U1AVIp4yxG8
# rwoRps9lyZ3l2mw+xD4MSYT2OqGWtJy/ksTToi7ecAvo6NJTWagsRl1sz6WeJseH
# d+PxrPrO4qNv7d6wsXUD/IY2DB6Fq9w1JAA9srGVpIVbEVJDwkAL515yvssELTOk
# YCuBL96O9tQFA0KVnwnLixshYDjPerXk2cl+BR+EI8HutM2NGNXOKwrutP4WnBhc
# MqvHC/jykkwy7kCPdJW3MZlBOXXspY7gfXeWC0ZzHyXdlw==
# SIG # End signature block
