
# Defines constants and getter functions for HPECOMCmdlets module


#Region Base URL endpoints

[String]$script:HPEGLAPIbaseURL = 'https://global.api.greenlake.hpe.com'
function Get-HPEGLAPIbaseURL { $script:HPEGLAPIbaseURL }

# Organizations API
[String]$script:HPEGLAPIOrgbaseURL = 'https://aquila-org-api.common.cloud.hpe.com'
function Get-HPEGLAPIOrgbaseURL { $script:HPEGLAPIOrgbaseURL }

# Account Management API
[String]$script:HPEGLUIbaseURL = 'https://aquila-user-api.common.cloud.hpe.com'
function Get-HPEGLUIbaseURL { $script:HPEGLUIbaseURL }

[String]$script:HPEOnepassbaseURL = 'https://onepass-enduserservice.it.hpe.com'
function Get-HPEOnepassbaseURL { $script:HPEOnepassbaseURL }

#EndRegion


#Region ---------------------------- COM PATHS -------------------------------------------------------------------------------------------------------------------------------------------

[String]$COMJobTemplatesUri = '/compute-ops-mgmt/v1beta2/job-templates'
function Get-COMJobTemplatesUri { $script:COMJobTemplatesUri }

[String]$COMActivationKeysUri = '/compute-ops-mgmt/v1beta1/activation-keys'
function Get-COMActivationKeysUri { $script:COMActivationKeysUri }

[String]$COMActivitiesUri = '/compute-ops-mgmt/v1beta2/activities'
function Get-COMActivitiesUri { $script:COMActivitiesUri }

[String]$COMOneViewAppliancesUri = '/compute-ops-mgmt/v1beta1/appliances' 
# [String]$COMOneViewAppliancesUri = '/compute-ops-mgmt/v1beta1/oneview-appliances' # requires OneView Edition subscription
function Get-COMOneViewAppliancesUri { $script:COMOneViewAppliancesUri }

[String]$COMApplianceFirmwareBundlesUri = '/compute-ops-mgmt/v1beta1/appliance-firmware-bundles'
function Get-COMApplianceFirmwareBundlesUri { $script:COMApplianceFirmwareBundlesUri }

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

[String]$COMEnergyByEntityUri = '/compute-ops-mgmt/v1beta1/energy-by-entity'
function Get-COMEnergyByEntityUri { $script:COMEnergyByEntityUri }

[String]$COMUtilizationByEntityUri = '/compute-ops-mgmt/v1beta1/utilization-by-entity'
function Get-COMUtilizationByEntityUri { $script:COMUtilizationByEntityUri }

#EndRegion


#Region ---------------------------- GLP PATHS -------------------------------------------------------------------------------------------------------------------------------------------


[uri]$ccsSettingsUrl = 'https://common.cloud.hpe.com/settings.json'
function Get-ccsSettingsUrl { $script:ccsSettingsUrl }

[uri]$AuthRedirecturi = 'https://auth.hpe.com/profile/login/callback'
function Get-AuthRedirecturi { $script:AuthRedirecturi }

[uri]$SchemaMetadataURI = $HPEOnepassbaseURL + '/v2-get-user-schema-metadata'
function Get-SchemaMetadataURI { $script:SchemaMetadataURI }

[String]$OpenidConfiguration = '/.well-known/openid-configuration'
function Get-OpenidConfiguration { $script:OpenidConfiguration }

[String]$SessionLoadAccountUri = $HPEGLUIbaseURL + '/authn/v1/session/load-account/'
function Get-SessionLoadAccountUri { $script:SessionLoadAccountUri }

[String]$AuthnUri = '/api/v1/authn'
function Get-AuthnUri { $script:AuthnUri }

[String]$AuthnSessionUri = $HPEGLUIbaseURL + '/authn/v1/session'
function Get-AuthnSessionUri { $script:AuthnSessionUri }

[String]$AuthnEndSessionUri = $HPEGLUIbaseURL + '/authn/v1/session/end-session'
function Get-AuthnEndSessionUri { $script:AuthnEndSessionUri }

[String]$AuthnSAMLSSOUri = $HPEGLUIbaseURL + '/authn/v1/saml/config'
function Get-AuthnSAMLSSOUri { $script:AuthnSAMLSSOUri }

[String]$AuthnSAMLSSOMetadataUri = $HPEGLUIbaseURL + '/authn/v1/saml/sp-metadata/'
function Get-AuthnSAMLSSOMetadataUri { $script:AuthnSAMLSSOMetadataUri }

[String]$SAMLAttributesUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/um/saml?domain='
function Get-SAMLAttributesUri { $script:SAMLAttributesUri }

[String]$SAMLValidateDomainUri = $HPEGLUIbaseURL + '/authn/v1/saml/validate_domain?domain='
function Get-SAMLValidateDomainUri { $script:SAMLValidateDomainUri }

[String]$SAMLValidateMetadataUri = $HPEGLUIbaseURL + '/authn/v1/saml/metadata/manual/'
function Get-SAMLValidateMetadataUri { $script:SAMLValidateMetadataUri }

[String]$AuthnSAMLSSOConfigUri = $HPEGLUIbaseURL + '/authn/v1/saml/async/config'
function Get-AuthnSAMLSSOConfigUri { $script:AuthnSAMLSSOConfigUri }

[String]$AuthnSAMLSSOConfigTaskTrackerUri = $HPEGLUIbaseURL + '/authn/v1/async-task-tracker/'
function Get-AuthnSAMLSSOConfigTaskTrackerUri { $script:AuthnSAMLSSOConfigTaskTrackerUri }

[String]$AccountSAMLNotifyUsersUri = $HPEGLUIbaseURL + '/accounts/ui/v1/customer/saml/notify/'
function Get-AccountSAMLNotifyUsersUri { $script:AccountSAMLNotifyUsersUri }

[String]$AuditLogsUri = $HPEGLAPIbaseURL + '/audit-log/v1/logs'
function Get-AuditLogsUri { $script:AuditLogsUri }

[String]$NewWorkspaceUri = $HPEGLUIbaseURL + '/accounts/ui/v1/customer/signup'
function Get-NewWorkspaceUri { $script:NewWorkspaceUri }

[String]$WorkspacesListUri = $HPEGLUIbaseURL + '/accounts/ui/v1/customer/list-accounts'
function Get-WorkspacesListUri { $script:WorkspacesListUri }

[String]$CurrentWorkspaceUri = $HPEGLUIbaseURL + '/accounts/ui/v1/customer/profile/contact'
function Get-CurrentWorkspaceUri { $script:CurrentWorkspaceUri }

[String]$MyUISessionUri = $HPEGLAPIOrgbaseURL + '/internal-sessions/v1alpha1/my-ui-session'
function Get-MyUISessionUri { $script:MyUISessionUri }

[String]$WorkspacesUri = $HPEGLAPIbaseURL + '/workspaces/v1/workspaces'
function Get-Workspacev1Uri { $script:WorkspacesUri }

[String]$WorkspacesV2Uri = $HPEGLAPIOrgbaseURL + '/organizations/v2alpha1/workspaces'
function Get-Workspacev2Uri { $script:WorkspacesV2Uri }

[String]$WorkspaceMigrationUri = $HPEGLAPIOrgbaseURL + '/internal-identity/v2alpha1/workspaces/'
function Get-WorkspaceMigrationUri { $script:WorkspaceMigrationUri }

[String]$DomainUri = $HPEGLAPIOrgbaseURL + '/identity/v1alpha1/domain-requests'
function Get-DomainUri { $script:DomainUri }

[String]$DomainDeleteUri = $HPEGLAPIOrgbaseURL + '/identity/v1alpha1/domains'
function Get-DomainDeleteUri { $script:DomainDeleteUri }

[String]$SSOConnectionUri = $HPEGLAPIOrgbaseURL + '/identity/v2alpha1/sso-profiles'
function Get-SSOConnectionUri { $script:SSOConnectionUri }

[String]$IdPValidateMetadataUrlUri = $HPEGLAPIOrgbaseURL + '/identity/v1alpha1/sso-profiles/idp-url'
function Get-IdPValidateMetadataUrlUri { $script:IdPValidateMetadataUrlUri }

[String]$IdPValidateMetadataFileUri = $HPEGLAPIOrgbaseURL + '/identity/v1alpha1/sso-profiles/metadata'
function Get-IdPValidateMetadataFileUri { $script:IdPValidateMetadataFileUri }

[String]$AuthenticationPolicyUri = $HPEGLAPIOrgbaseURL + '/identity/v1alpha1/sso-authentication-policies'
function Get-AuthenticationPolicyUri { $script:AuthenticationPolicyUri }

[String]$UsersUri = $HPEGLAPIOrgbaseURL + '/identity/v2beta1/scim/v2/Users'
function Get-UsersUri { $script:UsersUri }

[String]$UsersWithAuthSourceUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v2/um/users'
function Get-UsersWithAuthSourceUri { $script:UsersWithAuthSourceUri }

[String]$WorkspaceMembersUri = $HPEGLAPIOrgbaseURL + '/organizations/v2alpha1/workspaces'
function Get-UserTenantWorkspaceMembershipUri { $script:WorkspaceMembersUri }

[String]$WorkspaceUsersUri = $HPEGLAPIOrgbaseURL + '/workspaces/v2alpha1/workspaces'
function Get-WorkspaceUsersUri { $script:WorkspaceUsersUri }

[String]$UsersRolesUri = $HPEGLAPIOrgbaseURL + '/internal-platform-tenant-ui/v2/roles'
function Get-UsersRolesUri { $script:UsersRolesUri }

[String]$AuthzUsersRolesUri = $HPEGLUIbaseURL + '/authorization/ui/v2/customers/users/'
function Get-AuthzUsersRolesUri { $script:AuthzUsersRolesUri }

[String]$RoleAssignmentsV2Alpha2Uri = $HPEGLAPIOrgbaseURL + '/internal-platform-tenant-ui/v2alpha2/role-assignments'
function Get-RoleAssignmentsUri { $script:RoleAssignmentsV2Alpha2Uri }

[String]$AuthorizationRoleAssignmentsV2Alpha2Uri = $HPEGLAPIOrgbaseURL + '/authorization/v2alpha2/role-assignments'
function Get-AuthorizationRoleAssignmentsV2Alpha2Uri { $script:AuthorizationRoleAssignmentsV2Alpha2Uri }

[String]$ScimUserGroupsUri = $HPEGLAPIOrgbaseURL + '/identity/v2alpha1/scim/v2/extensions/Users'
function Get-ScimUserGroupsUri { $script:ScimUserGroupsUri }

[String]$CreateUserUri = $HPEGLAPIOrgbaseURL + '/internal-platform-tenant-ui/v2alpha2/users'
function Get-CreateUserUri { $script:CreateUserUri }

[String]$InviteUserUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/um/invite-user'
function Get-InviteUserUri { $script:InviteUserUri }

[String]$ReInviteUserUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/um/resend-invite'
function Get-ReInviteUserUri { $script:ReInviteUserUri }

[String]$UserPreferencesUri = $HPEGLUIbaseURL + '/user-prefs/v1alpha1/preferences'
function Get-UserPreferencesUri { $script:UserPreferencesUri }

[String]$SaveUserPreferencesUri = $HPEGLUIbaseURL + '/user-prefs/v1alpha1/save-preferences'
function Get-SaveUserPreferencesUri { $script:SaveUserPreferencesUri }

[String]$DevicesUri = $HPEGLAPIbaseURL + '/devices/v1/devices'
function Get-DevicesUri { $script:DevicesUri }

[String]$DevicesUIDoorwayUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/devices'
function Get-DevicesUIDoorwayUri { $script:DevicesUIDoorwayUri }

[String]$DevicesAddUri = $HPEGLAPIbaseURL + '/devices/v1beta1/devices'
function Get-DevicesAddUri { $script:DevicesAddUri }

[String]$DevicesStatsUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/devices/stats'
function Get-DevicesStatsUri { $script:DevicesStatsUri }

[String]$DevicesApplicationInstanceUri = $HPEGLAPIbaseURL + '/devices/v1/devices'
function Get-DevicesApplicationInstanceUri { $script:DevicesApplicationInstanceUri }

[String]$DevicesATagsUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/devices/tags'
function Get-DevicesATagsUri { $script:DevicesATagsUri }

[String]$DevicesLocationUri = $HPEGLAPIbaseURL + '/locations/v1/locations'
# [String]$DevicesLocationUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/locations'
function Get-DevicesLocationUri { $script:DevicesLocationUri }

[String]$SubscriptionsUri = $HPEGLAPIbaseURL + '/subscriptions/v1/subscriptions'
function Get-SubscriptionsUri { $script:SubscriptionsUri }

[String]$LicenseDevicesUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/license/devices'
function Get-LicenseDevicesUri { $script:LicenseDevicesUri }

[String]$AddLicenseDevicesUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/customers/license'
function Get-AddLicenseDevicesUri { $script:AddLicenseDevicesUri }

[String]$RemoveLicensesUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/license/unclaim'
function Get-RemoveLicensesUri { $script:RemoveLicensesUri }

[String]$PreclaimLicenseUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/license'
function Get-PreclaimLicenseUri { $script:PreclaimLicenseUri }

[String]$LicenseDevicesProductTypeDeviceUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/license?product_type=DEVICE'
function Get-LicenseDevicesProductTypeDeviceUri { $script:LicenseDevicesProductTypeDeviceUri }

[String]$ServiceSubscriptionsListUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/license/service-subscriptions'
function Get-ServiceSubscriptionsListUri { $script:ServiceSubscriptionsListUri }

[String]$AutoSubscriptionSettingsUri = $HPEGLAPIbaseURL + '/subscriptions/v1/auto-subscription-settings'
function Get-AutoSubscriptionSettingsUri { $script:AutoSubscriptionSettingsUri }

[String]$AutoReassignmentSettingsUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/license/auto-renewal'
function Get-AutoReassignmentSettingsUri { $script:AutoReassignmentSettingsUri }

[String]$ApplicationsProvisionsUri = $HPEGLUIbaseURL + '/ui-doorway/ui/v1/applications/provisions'
function Get-ApplicationsProvisionsUri { $script:ApplicationsProvisionsUri }

[String]$RegionsUri = $HPEGLUIbaseURL + '/geo/ui/v1/regions'
function Get-RegionsUri { $script:RegionsUri }

# Used by deprecated Get-HPEGLServiceResourceRestrictionPolicy function (legacy RRP endpoint)
[String]$AuthorizationResourceRestrictionsUri = $HPEGLUIbaseURL + '/authorization/ui/v1/resource_restrictions' 
function Get-AuthorizationResourceRestrictionsUri { $script:AuthorizationResourceRestrictionsUri }

[String]$InternalAuthorizationResourcesUri = $HPEGLAPIOrgbaseURL + '/internal-authorization/v2alpha1/resources'
function Get-InternalAuthorizationResourcesUri { $script:InternalAuthorizationResourcesUri }

[String]$ScopeGroupsV2Alpha1Uri = $HPEGLAPIOrgbaseURL + '/authorization/v2alpha1/scope-groups'
function Get-ScopeGroupsUri { $script:ScopeGroupsV2Alpha1Uri }

[String]$ApplicationsLoginUrlUri = $HPEGLUIbaseURL + '/authn/v1/onboarding/login-url/'
function Get-ApplicationsLoginUrlUri { $script:ApplicationsLoginUrlUri }

[String]$ApplicationsAPICredentialsUri = $HPEGLUIbaseURL + '/authn/v1/token-management/credentials'
function Get-ApplicationsAPICredentialsUri { $script:ApplicationsAPICredentialsUri }

# Legacy RRP URI - Not currently used (reserved for backward compatibility)
[String]$ResourceRestrictionsPolicyUsersUri = $HPEGLUIbaseURL + '/authorization/ui/v2/resource_restriction/'
function Get-ResourceRestrictionsPolicyUsersUri { $script:ResourceRestrictionsPolicyUsersUri }

[String]$AuthZApplicationsUri = $HPEGLUIbaseURL + '/authorization/ui/v1/applications/'
function Get-AuthZApplicationsUri { $script:AuthZApplicationsUri }

# [DEPRECATED] Legacy Resource Restriction Policy (RRP) API endpoints
# HPE GreenLake has replaced RRP with Scope-Based Access Control (SBAC)
# These constants are maintained for backward compatibility with deprecated functions
# Use Get-HPEGLServiceScopeFilter and scope group functions instead
[String]$ResourceRestrictionPolicyUri = $HPEGLUIbaseURL + '/authorization/ui/v1/resource_restriction/'
function Get-ResourceRestrictionPolicyUri { $script:ResourceRestrictionPolicyUri }

[String]$SetResourceRestrictionPolicyUri = $HPEGLUIbaseURL + '/authorization/ui/v1/customers/applications'
function Get-SetResourceRestrictionPolicyUri { $script:SetResourceRestrictionPolicyUri }

[String]$DeleteResourceRestrictionPolicyUri = $HPEGLUIbaseURL + '/authorization/ui/v1/resource_restriction/delete'
function Get-DeleteResourceRestrictionPolicyUri { $script:DeleteResourceRestrictionPolicyUri }

[String]$ApplicationInstancesUri = $HPEGLUIbaseURL + '/authorization/ui/v1/application_instances'
function Get-ApplicationInstancesUri { $script:ApplicationInstancesUri }

[String]$ApplicationProvisioningUri = $HPEGLUIbaseURL + '/app-provision/ui/v1/provisions'
function Get-ApplicationProvisioningUri { $script:ApplicationProvisioningUri }

[String]$ServiceManagersUri = $HPEGLAPIbaseURL + '/service-catalog/v1beta1/service-managers'
function Get-ServiceManagersUri { $script:ServiceManagersUri }

[String]$OrganizationsListUri = $HPEGLAPIOrgbaseURL + '/organizations/v2alpha1/organizations'
function Get-OrganizationsListUri { $script:OrganizationsListUri }

[String]$OrganizationsUsersListUri = $HPEGLAPIOrgbaseURL + '/identity/v2beta1/scim/v2/Users'
function Get-OrganizationsUsersListUri { $script:OrganizationsUsersListUri }

[String]$OrganizationsUsersGroupsListUri = $HPEGLAPIOrgbaseURL + '/identity/v2beta1/scim/v2/Groups'
function Get-OrganizationsUsersGroupsListUri { $script:OrganizationsUsersGroupsListUri }



#EndRegion


#Region ---------------------------- VARIABLES -------------------------------------------------------------------------------------------------------------------------------------------

[string]$APIClientCredentialTemplateName = 'COM_PS_Library_Temp_Credential'
function Get-APIClientCredentialTemplateName { $script:APIClientCredentialTemplateName }

#EndRegion


# No Export-ModuleMember to keep functions private
# SIG # Begin signature block
# MIItTgYJKoZIhvcNAQcCoIItPzCCLTsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDR3kHiZ2SLI5C2
# XvXIG7W9WRiVopMT+Cr2IhYCZk8BPaCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgVcO+SGTX/tLnkFbYPf/nf6g/VTeRhoMw+CbHZ+2tkXkwDQYJKoZIhvcNAQEB
# BQAEggIAPs75iJFviR5hMeTA9KVn4AHIdTWmL8Vu4/Vzjq+qZ08v5225d6lDEui6
# RnH8Fl5zi05AE6UIfmGlgYYLdcQPU0Cx1De02xZTRaUWrxLBBzi/vKnTMzENeCuQ
# 5/j6Lcs7LK8lBctlFksvYWvpR0VLvPBAydT2dqmmp34Ulb743QYSKD5gFOoo+bDC
# 3NZB7M2lznIqxnTGvBrlRfeNE5liLIXSTG95rgaH3CcxoFpo0biLacw2xG7gdoFf
# /F4r3KYUuZPWAwXxvCZsGOJznvLGL5M2LBuYgnt9VQZS6oqiZAp21R3cNaJ8B2pT
# Gt3bwLXwdCNDyjsuWKmWVeoZgzzECbEhXvUWE5M8yLoqyiizWeMUCtwmSH1hfT5K
# 4uRHsJLTM9hNxCYFPE5inGRhKepFo1saOOD0B1erTMtPSNwvd68V4tOD9QqpQV9F
# txh+vd4tuTV8JUSGDkHHLPtBMm3bKUGFEhJXgrSLtiVGxf3OEQIlQJNl6em+4dTb
# aOS8fQojFSTXOOKJuviw188KPJ0zuuC7n2WlTY0igrmKoAfo4LLnK3gdpVFxj22/
# 66FBIdbuIzWw8UYglvxjXdMCoTnjY/WnwVpTulGNCOIuTPrsYswu/BvFqFXSENcc
# Hf3FxFu6ACFImzQWiXZ47BheEJKRhElCvDfDBVHlNujHrz2Os5OhgheYMIIXlAYK
# KwYBBAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMLPzsaHCGd8U2j0/hBEqNgsgT6Fkg+BnZOSQRCFr03vU
# sVybfsBhAaKUhnBgQTtPuwIRAMDDm3zOXr9DIrUbWhAGhAMYDzIwMjYwMTE5MTgy
# MjM4WqCCEzowggbtMIIE1aADAgECAhAMIENJ+dD3WfuYLeQIG4h7MA0GCSqGSIb3
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
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDEx
# OTE4MjIzOFowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQUcrz9oBB/STSwBxxhD+bX
# llAAmHcwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgMvPjsb2i17JtTx0bjN29j4uE
# dqF4ntYSzTyqep7/NcIwPwYJKoZIhvcNAQkEMTIEMJIY3iThdIHUh7Ef0AiWmJIa
# YqvPGcKiu4H0BS2H0uA5RKM0DnPuf3tob+/N389oWTANBgkqhkiG9w0BAQEFAASC
# AgApua0PVOvZXVKQNIhuwpvBvEb1+B270Nq+aKTEiE1F5enrbMINSrZHS8d+cq4M
# X6o1xpLvzI495AhOn0rBH1F6EFf1uy2N+mZHJnmC/Md+OUHSpqUubpUAilBvex1G
# wDc8YbfLcZnsmckaFF9gWLe0xR1+rUt4ySoutXRmY3EVNFN50784nI/bWvyQ8mRC
# hRe4eq4blgTOjw6DrrJhJ3DCePk7DLEVQnosokdkZ35wATUK47wKtiyjLqbp+yNk
# 4xQq9o2NDmbxc3SbuY46/5Etms+uogNzP2vMSWMuVc/mjyapPl1WHpzztg/lgN6h
# fMN6NnnjGL2UPYlv8jZVWJUp+RzjHyI8Bq547SKcHyakFIzQntrjoay43r9ueFxR
# wqNdVvQY9/CsjAZT/xtiOA8k8g0Y+94Ji+kmzw8P/LLH2vl/GBQ1dndZy6cc2b0Y
# q2+8oYPSDbAuI4OQUT8zpE6zS48Zt2y5Dppc8HCIsSXhmUfVLaekdBb078iwl1lK
# VIjOnCT8vGOCrped5xTxoubm9A59xXsgIiSUna6jMpWFPWNmtxDSg/S8iEZusPKF
# HFOY6LVUpPuS+R4fqP3vfCRAr6cZjtkdPJ4Gnapw64QHwzsV9h0EiDlxh8GzRNFS
# KfGMx0kKapLcnyw1aJDSTDcFNELmlKDE8H4/fWg9l6mrnw==
# SIG # End signature block
