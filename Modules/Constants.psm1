
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
# MIIunwYJKoZIhvcNAQcCoIIukDCCLowCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBTDj923ntGcP4y
# NFuDavx19z54DaJ/4i8dKdd3euqskaCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgZKVisXsYsLp33yzFrOs0uGNEXpWfkx7QJfmC7+ySAF0wDQYJKoZIhvcNAQEB
# BQAEggIADKd9jtELc8ZdhDr3eggsxykny7ddMU+fhtwsT0z5BaXtoSSgoBm/+MoH
# snbMKr1olUrMbRSuTcTWtagmhFsSbliIuNHuTO0SA/4wq7296ZrjBfX4eDEMsQsz
# ILbSMJBSHEFeE7jb0HV4QfzmI8c1+FRD8m5oNwkFmyJe+Lv9p8bMl3glzac/8G15
# Oa1rKFzr1W8faVuLQW2qKLj9NqYVWkZcPC6MRUH8Y52jaUdyaeP6Y15RRGGvQAP0
# g6wSKFVyk7Ag4ZCUSQHlN43gixaFuoaDngjN7yHumTrBMqhkb/lKEWn8bpwmN0kY
# 6pGCAkHhEXeXqivPAaRnQtsjZEfBako7LgnxX9qjowSehrNKe6Vd72Po/6nnDjux
# 4uNipHYrrRJ2qUYM7z21JmPJXgNOua96U6xHpsB/Zl4NvO+7ugmJx6EuTc0t4+IY
# ANKq6DoUwuHJwMIFo5wFP4++nJQGhbNOHk6LJVC3TJcQvEfBZl4GXmit66O6ci+N
# K3ocvuGowrT+HjRGT/5cUvjthW7ul3xZ/RK0enORijN77FNyVQvTrlgd5Dkt8LSm
# JQk7JvAliRFa4gCfIFI1fkrWAMVYYZGZdGovEw7BtiuMSJco08C1CAfoTCXoLMTH
# V1mSA3a22ubFgEdt8O3B9rcmfYEzvowoEz4OxmhcVmgpqyUGBd+hghjpMIIY5QYK
# KwYBBAGCNwMDATGCGNUwghjRBgkqhkiG9w0BBwKgghjCMIIYvgIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwpg434cAvtskhyPwuw07eX1+yUAi4OGvMrCwR
# 1W6gleB4egWZlpK9mDSaccTPxkhHAhUA8mRqteFj9YWWYya+cnVu144yTHYYDzIw
# MjYwMTMwMTA1MTQ5WqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3Qg
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
# MQ8XDTI2MDEzMDEwNTE0OVowPwYJKoZIhvcNAQkEMTIEMNA9qufY0qoHr+4EldsW
# Ep5LOuJgr6bfHTkQDdHca/ELwoM5YvOb9bPwDn7fCaqWaTCCAXoGCyqGSIb3DQEJ
# EAIMMYIBaTCCAWUwggFhMBYEFDjJFIEQRLTcZj6T1HRLgUGGqbWxMIGHBBTGrlTk
# eIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HIPlz0x+M/MIG8BBSFPWMtk4KCYXzQ
# kDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5l
# dyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNF
# UlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAE
# ggIATwEaL+5kVTenpQDdm++CSa7HSEdLZzr07qLXgFrN5YHhFA/jfVcu1Bp8aO2y
# z6Zlb5XhahnoVdoYYj2YAGYgcz78H5vzC1PusQYL0WN1Bth0N6FO1YrLsvzihaTg
# JIWeBfRKOq7SgqG1SHsWLYscQ1wnpa7DIDJi1UrgIEi8UFKEA3BwcKIXb53i2PPI
# drPOVxjqFrNHZxDXvsH7e5FgxDMdwJfqnslCyFyS/3BVS5a+yjQ2CcheVJOwy9S8
# B1iOcL4lVAxCZtbUHqm3GrJSiSS29AcstSeimAtUNbkr/VomJP8GIxWK8quGSKlA
# ccZDViIbL+uli0s9VZrktOKHl3u6lxTtjff/mD3d+Wl2bEow1dyerxlj8a8v8aNT
# 4Fa5rrBYJl10kHIsywdroyGiGjPxehRl6ciLNAUTzBaWz5o5phOoAmjNZytsmfKA
# 8uolOgP4kgxT1X0HSE6LLXRkIj1rLgbfqpwnq4UzH/xv2loWWey/P3wXP80oSoGD
# rBb+hGkiZOMRUuHOdowI239otB1wblpnkPTDeVvICbwDs1O3EigdeqjgLNdZjFNG
# bnK7c3u+kXzdnllinprHz43Y74JEU9ZEGYJfalsD7NIUvQmtutXEufs1yO7SkIp+
# qK39PntVRASRGCl8QizLV8XQDnewcgAA3EX/n1/VImttCLs=
# SIG # End signature block
