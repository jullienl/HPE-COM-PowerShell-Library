
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

[String]$GLWebhooksUri = $HPEGLAPIbaseURL + '/events/v1beta1/webhooks'
function Get-GLWebhooksUri { $script:GLWebhooksUri }

[String]$GLSubscriptionsUri = $HPEGLAPIbaseURL + '/events/v1beta1/subscriptions'
function Get-GLSubscriptionsUri { $script:GLSubscriptionsUri }

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

[String]$DevicesAddUri = $HPEGLAPIbaseURL + '/devices/v1/devices'
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

[String]$LocationsTagsUri = $HPEGLAPIbaseURL + '/locations/v1/locations/tags'
function Get-LocationsTagsUri { $script:LocationsTagsUri }

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
# MIItTQYJKoZIhvcNAQcCoIItPjCCLToCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDfpCpVaoC+lH2z
# E0eAYhU+GZjOFVIcZc+LshOfcJJ6B6CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# nZ+oA+rbZZyGZkz3xbUYKTGCGq0wghqpAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQg3l9qEQvjmlWLYwBISwQsIhpaV5aYnHBH8j51izP+P7owDQYJKoZIhvcNAQEB
# BQAEggIAhJJWCjNTWRHPro4zeVTxFIarb1QiJFFiaAly7iZeJbH/cn4FiDG1UtHS
# TbbY1H1L4oWWit6QtU7roiU5eCoRbiMp73WNT4JdkdTluxAlgCDFb0al0K4A4Z4Z
# 4gZKb41Si9nm3T6RxbFH1xgDeh7j5TEaPEXXimpG6qdvtNnzDKPCKQKORXz7Tyxy
# tvZwCRF75e9WKmA3mRUAzP0wZZmU/L42QVyYLfdUGGdS9F70Oky/U1j6MW48GpfP
# LtOpf2GjflNnEV0N5P8KCXFkJihpH/vtpWJawoRAZbOT9Ek8X4iZXccEHmOp3B9B
# dUxQuFcZ1QsSktrY+Lq5RCEA4aTmGFuZkvztNidnF/LyeHAuEhfJdep4bYsVCRC6
# NlOug3sgzylCL/YvUaUA6K/A4tT5HptQytdxz6LceBVzpvmW2NV1QkOlQxeClf+V
# jL2UyTLjT5A9E4PFm70daYZxipFmIfG7Y66gLSwuRVYf7Gz+CqVU197PYZ8qWOAM
# cn0lJITy7A+AZxDlysl2WKTG7z6VCYbdg6nEvepqItC81eyGrXL08nYuHNMWNqt0
# JHuEr8PDuYl6sS1DGb2K0LArd323nMmRa/OlLeuE4nV05YI6Z8iAoeU2n0B1C4v8
# zHUsbdAZfyn2KHiW8aXbs5GCV+qfYs2M0RiQPa2ltlHutmiXTB2hgheXMIIXkwYK
# KwYBBAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMIo9+nAGmXmsmt/4xPdPgufUSNgfaXTfj7/S+KMa+3oI
# U2zAnZsGgC6P90pBuR456wIQIRn2hM3V7sAGXZKwTRb5gBgPMjAyNjAzMTcxNDMz
# MDlaoIITOjCCBu0wggTVoAMCAQICEAwgQ0n50PdZ+5gt5AgbiHswDQYJKoZIhvcN
# AQEMBQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEw
# PwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2
# IFNIQTI1NiAyMDI1IENBMTAeFw0yNTA2MDQwMDAwMDBaFw0zNjA5MDMyMzU5NTla
# MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UE
# AxMyRGlnaUNlcnQgU0hBMzg0IFJTQTQwOTYgVGltZXN0YW1wIFJlc3BvbmRlciAy
# MDI1IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDbOVL7i3S35ckN
# Udj680nGm/v3iwzc7hRDJyYpFeZguz5hF/O3KXxAnuf9SrE1MpaaN0UNYa/jf5ra
# iInjXLE57SwugXHwXVrPYlFNlzt2EDFud75vJ3lt/ZIRmUKu4bHFZKpulRjp0AZE
# ILIE5qIVqheGSf4vXl59yiYNKtOcDlWB32m8w77tsz61JbgnMCIhs7aYg/IIR0pi
# xyY+X5gG56dI/s0nD2JwvW1amfrW4zpbJQ2/hFzIEDP428ls1/mRMzsXjpy8HCnS
# VliKxlH3znLmxiPh7jJQFs8HHKtPlo0xn77m2KzwYOYcKmrJUtDh4sfCmKbmLBHj
# 1NER8RO2UQU5FZOQnaE47XPNUBazqO116nXZW0VmhA6EjB1R88dKwDDf3EVV68UQ
# V/a74NWvWw5XskAJj7FwbyFYh6o8ZVTCSLIFFROADsd4DElvSJCXgYMELpkEDjAY
# 39qEzEXh+4mw6zXPCQ8FKdeYeSbXwfAeAg8qTbzt0whyFnKObvMZwJhnhuKyhRhY
# v2hOBr0kJ8UxNz3KXbpcMHTOX2t1LC+I6ZphKVpFqcXzijEBieqAHLpnz3KQ+Bad
# vtJGLfU3I/fn1aGiT7fp+TLFM+NKsJa8wrunNtGDy18hGVSfGXsblsiuQ+oxsP3M
# mgHv0wcWAuvmWNTuutwvDL5wR+nMUwIDAQABo4IBlTCCAZEwDAYDVR0TAQH/BAIw
# ADAdBgNVHQ4EFgQUVZ6552fIkRBJtDZSjXm3JMU/LfgwHwYDVR0jBBgwFoAU729T
# SunkBnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoG
# CCsGAQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2
# U0hBMjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL2NybDMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5
# NlNIQTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG
# /WwHATANBgkqhkiG9w0BAQwFAAOCAgEAG34LJIfYCWrFQedRadkkjuul0CqjQ9yK
# TJXjwu2TlBYWDGkc/1a2NHeWyQQA6TdOzOa43IyJ3tW7EeVAmXgpx1OvlxDZgvL6
# XnrSl4GAzuQDgcImoap1B3ONfKuWDdgJ1+eOz3D/sE7zFSaUBqr8P49Nlk74yfFr
# f8ijJiwX4v2BZfhUnFkuWNWzkkqalKiefKwxi/sJqqRCkEOYlZTYXryYstld9TTB
# dsPL1BBOySBwe+LJAN4HWXqOX9bA5CJI1M1p9hBRHZmwnms8m7U0/M7WG0rB2JSN
# Z6cfCrkFErUFHv4P5PAb3tQdfhXRb4m8VmnzPd3cbmwDs+32o7n/oBZn7TJ/yc3n
# wP4cABKEeafLbm3pbuoXpVJFkIikavyFsCN9sGE7gxjwbZT3PBUqnpKWO4qSfF3Z
# u6KE7fd2KgIawHq2tf77FAp/hCVhKCAW8P1lZIbjKwk9g7H6FuwFMQ40W2v33Ho6
# AmefJWQOi50if6CZX4Gr5rYb74EtTkBc5VyUTGm6hRBdRkXmnexSt3bVCMX1FrTH
# hEPTaBLhfCDM362+5j62OE8gLBeYfcREv588ijFlPReDBU/7XtSpRuLlml7hh1p0
# blaMJMG+2aUzglWi8ZhG/IDJ+ZgknHT/RP6orTnBEmmDirzW84q4JA9oT0f30kJW
# 98IMGbgqOsQwgga0MIIEnKADAgECAhANx6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3
# DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAX
# BgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0
# ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAwMDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJ
# BgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGln
# aUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAy
# NSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC0eDHTCphBcr48
# RsAcrHXbo0ZodLRRF51NrY0NlLWZloMsVO1DahGPNRcybEKq+RuwOnPhof6pvF4u
# GjwjqNjfEvUi6wuim5bap+0lgloM2zX4kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNn
# QxqXmRinvuNgxVBdJkf77S2uPoCj7GH8BLuxBG5AvftBdsOECS1UkxBvMgEdgkFi
# DNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2Ws3IfDReb6e3mmdglTcaarps0wjUjsZv
# kgFkriK9tUKJm/s80FiocSk1VYLZlDwFt+cVFBURJg6zMUjZa/zbCclF83bRVFLe
# GkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9oHRaQT/aofEnS5xLrfxnGpTXiUOeSLsJy
# goLPp66bkDX1ZlAeSpQl92QOMeRxykvq6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz
# 7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+rx3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36
# czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvUBDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQb
# U2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0
# qVjPKOWug/G6X5uAiynM7Bu2ayBjUwIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgw
# BgEB/wIBADAdBgNVHQ4EFgQU729TSunkBnx6yuKQVvYv1Ensy04wHwYDVR0jBBgw
# FoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6
# MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# Um9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJ
# KoZIhvcNAQELBQADggIBABfO+xaAHP4HPRF2cTC9vgvItTSmf83Qh8WIGjB/T8Ob
# XAZz8OjuhUxjaaFdleMM0lBryPTQM2qEJPe36zwbSI/mS83afsl3YTj+IQhQE7jU
# /kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKC
# hHyfpzee5kH0F8HABBgr0UdqirZ7bowe9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA
# 0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1UH410ANVko43+Cdmu4y81hjajV/gxdEkM
# x1NKU4uHQcKfZxAvBAKqMVuqte69M9J6A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qI
# ijanrUR3anzEwlvzZiiyfTPjLbnFRsjsYg39OlV8cipDoq7+qNNjqFzeGxcytL5T
# TLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0vw9vODRzW6AxnJll38F0cuJG7uEBYTpt
# MSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/DJbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+
# 7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHbxtl5TPau1j/1MIDpMPx0LckTetiSuEtQ
# vLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAPvIXKUjPSxyZsq8WhbaM2tszWkPZPubdc
# MIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBl
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJv
# b3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7J
# IT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxS
# D1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb
# 7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1ef
# VFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoY
# OAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSa
# M0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI
# 8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9L
# BADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfm
# Q6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDr
# McXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15Gkv
# mB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
# FgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGL
# p6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0Eu
# Y3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0G
# CSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6p
# Grsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1W
# z/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp
# 8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglo
# hJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8S
# uFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMYIDjDCCA4gCAQEwfTBp
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMT
# OERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2
# IDIwMjUgQ0ExAhAMIENJ+dD3WfuYLeQIG4h7MA0GCWCGSAFlAwQCAgUAoIHhMBoG
# CSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYwMzE3
# MTQzMzA5WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBRyvP2gEH9JNLAHHGEP5teW
# UACYdzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCAy8+OxvaLXsm1PHRuM3b2Pi4R2
# oXie1hLNPKp6nv81wjA/BgkqhkiG9w0BCQQxMgQwuGNUtG1LJ/iKzH/ny1XX6IKp
# 0Kucc0v9Drj3N2gGdS+C4F5Y7zUKYQXEp3oe8S1yMA0GCSqGSIb3DQEBAQUABIIC
# AEC+5ti7al1kcpHp4tStWodEFckPaeZO0Jojom/S81X8UfiEJi5/HXdePDwTjtuM
# 3P985pkQxgiBvERD1s5I7b1F5teAADrcwGzMo2mIKh/DVXqpDXfxrcl9E++Tz+Wx
# Ew2gBlOxvrbAEXdmGuHDBQ7xqjKG5h86TwrOscd/qMQNnlTQuCGka9yzeVT60vtP
# 5KNk7y6L3f7ErrsIDrty6W7w3nYo6JGO6EhwtPULAs0ir+ZDHt+6bv/7jz48v/Yi
# b5cDsSSOxIhTx7y8pvTQKyhGZmi5XYt2cRnBw/69aCbcea5EAmIgFM5RSY3ubkya
# zzy4o8SzNNKe4RZCL4XrAl2GrQ7CmbhAqayKx2xK99vP81K68v9Y6L/2XehJ3OyU
# wJXcAENeS8DOKj5MBT4LEdwHqo+8rCG5kdsLuKNVdKma0sF/Z+nzgJcsa3Ad6HhA
# xA1NSuA4dk5/CQ8di1ffACXhBiSNV2O4S6jnilV6Ji+x8q2mWPy1EFJ9dLHLGWwV
# EK6/YQ7N463ufF0Et8+MaSMyJLmcgeTYbjhOjL6Z2X9COioAOx089dKM45Z89hv/
# qQvwcZKnqD3wm9XX3ErAu81ZsoqV4oKMWg7y9TVwEZNGC6pT4mEoKdpuSo5DNex7
# XuAbXOdrQVf3T4OqBomou8Pu32Bi+T2FVi+bqWDGBXS/
# SIG # End signature block
