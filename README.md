# HPE Compute Ops Management PowerShell Library 

The HPE Compute Ops Management PowerShell library (`HPECOMCmdlets`) offers a comprehensive suite of cmdlets designed to manage and automate your HPE GreenLake environment. By leveraging this library, users can seamlessly interact with HPE GreenLake and Compute Ops Management services directly from the PowerShell command line, enabling efficient integration into existing automation workflows and enhancing operational efficiency.

This library is actively maintained with continuous updates to support new HPE GreenLake features as they are released.

> 💬 **Need help or found a bug?**  
> - 🐛 [Open a bug report](https://github.com/jullienl/HPE-COM-PowerShell-Library/issues/new/choose) - please include verbose output (`Connect-HPEGL ... –Verbose *> verbose.txt`)  
> - 💬 [Ask a question in GitHub Discussions](https://github.com/jullienl/HPE-COM-PowerShell-Library/discussions)

## Latest Release

| Version | Last Updated | Downloads | Status | PowerShell |
|---------|--------------|-----------|--------|------------|
| 1.0.26 | June 2026 | [![PS Gallery][GL-master-psgallery-badge]][GL-master-psgallery-link] | [![Build Status](https://img.shields.io/badge/status-stable-green)](https://github.com/jullienl/HPE-COM-PowerShell-Library) | [![PowerShell 7+](https://img.shields.io/badge/PowerShell-7%2B-blue)](https://github.com/PowerShell/PowerShell) |

📋 **[Release Notes & Changelog](Build-Tools/Release%20notes)** - see what's new in each version.


## Table of Contents
- [Documentation & Tutorials](#documentation--tutorials)
- [Quick Start](#quick-start)
- [Requirements](#requirements)
- [Best Practices & Performance Considerations](#best-practices--performance-considerations)
- [Supported Authentication Methods](#supported-authentication-methods)
  - [Single-factor authentication with HPE Account](#single-factor-authentication-with-hpe-account)
  - [Multi-factor authentication (MFA) with HPE Account](#multi-factor-authentication-mfa-with-hpe-account)
  - [SAML Single Sign-On (SSO) - Passwordless and Password-based](#saml-single-sign-on-sso--passwordless-and-password-based)
    - [Okta Identity Engine (OIE) Requirement](#okta-oie-requirement)
- [Installation](#how-to-install-the-module)
- [Upgrade](#how-to-upgrade-the-module)
- [How to Connect to HPE GreenLake and Compute Ops Management](#how-to-connect-to-hpe-greenlake-and-compute-ops-management)
  - [Session Management](#session-management)
  - [Authentication Examples](#authentication-examples)
    - [Example 1: Direct authentication with username and password](#example-1-direct-authentication-with-username-and-password)
    - [Example 2: SAML SSO with Okta (push notification with number matching)](#example-2-saml-sso-with-okta-push-notification-with-number-matching)
    - [Example 3: SAML SSO with Microsoft Entra ID (push notification with number matching)](#example-3-saml-sso-with-microsoft-entra-id-push-notification-with-number-matching)
    - [Example 4: SAML SSO with PingIdentity (push notification)](#example-4-saml-sso-with-pingidentity-push-notification)
    - [Example 5: Connect without specifying workspace](#example-5-connect-without-specifying-workspace)
    - [Example 6: Enable verbose output for troubleshooting](#example-6-enable-verbose-output-for-troubleshooting)
    - [Example 7: Connecting to the Pavo Pre-Production Environment (Optional)](#example-7-connecting-to-the-pavo-pre-production-environment-optional)
  - [Global Variables Reference](#global-variables-reference)
- [Onboarding Servers to Compute Ops Management](#onboarding-servers-to-compute-ops-management)
- [Support](#support)
- [Common Issues and Solutions](#common-issues-and-solutions)
- [Telemetry](#telemetry)
- [Disclaimer](#disclaimer)
- [Additional Resources](#additional-resources)
- [License](#license)



## Documentation & Tutorials

**📘 Blog & Guides**: For detailed insights, step-by-step tutorials, and the latest updates, visit:
- 🧪 **[Hands-On Lab: HPE Compute Ops Management Zero-Touch Automation](https://hpelabs.github.io/PowerShell-COM-Zero-Touch/)** - A self-paced, guided lab that takes you through the full server lifecycle with the module - installing HPECOMCmdlets, connecting to HPE GreenLake (credentials or SAML SSO), creating a workspace, provisioning COM, onboarding a server, building settings and groups, checking compliance, scheduling firmware updates, exploring inventory/health/sustainability insights, iLO SSO access, and cleanup
- 🚀 **[HPE Compute Ops Management Zero Touch Automation Example](https://github.com/jullienl/HPE-COM-PowerShell-Library/blob/main/Examples/COM-Zero-Touch-Automation.ps1)** - Learn best practices with a complete automation example covering the entire infrastructure deployment lifecycle showcasing workspace creation, zero-touch server onboarding, configuration, firmware updates, and teardown
- 🔌 **[Bulk iLO Onboarding to Compute Ops Management](https://github.com/jullienl/HPE-Compute-Ops-Management/blob/main/PowerShell/Onboarding/Prepare-and-Connect-iLOs-to-COM-v2.ps1)** - Production-grade, idempotent script to onboard HPE Gen10 and later servers at scale from a CSV file, automating GreenLake authentication, iLO DNS/SNTP configuration, firmware-compliance updates, activation-key generation, COM connection (direct, web proxy, or Secure Gateway), location and tag assignment, and CSV status reporting, with a `-Check` pre-flight mode
- 🛡️ **[Discover and Onboard iLOs via Secure Gateway](https://github.com/jullienl/HPE-Compute-Ops-Management/blob/main/PowerShell/Onboarding/Discover-and-Onboard-iLOs-via-SecureGateway.ps1)** *(v1.0.26+)* - Secure-Gateway-native onboarding script that discovers every iLO behind an HPE Secure Gateway and onboards them in a single batch job - no CSV of IP addresses and no local firmware staging required (the gateway discovers the iLOs and updates their firmware server-side). Automates GreenLake authentication, COM instance / Secure Gateway / subscription / location validation, optional iLO DNS/NTP, subscription, location, tags and service-delivery contact, shared **or** per-iLO credentials (CSV), with a `-Check` pre-flight triage table and CSV status reporting
- 🎯 **[Configuring SAML SSO with HPE GreenLake for the Top 3 Identity Providers](https://jullienl.github.io/Configuring-SAML-SSO-with-HPE-GreenLake-and-Passwordless-Authentication-for-HPECOMCmdlets)** - Step-by-step guide to setting up SAML SSO with Microsoft Entra ID, Okta, and Ping Identity, then signing in from HPECOMCmdlets using passwordless (push/TOTP) or password-based (`-Credential`, v1.0.26+) authentication

---

## Quick Start

Get up and running in 4 steps:

1. **Install the module**
    ```powershell
    Install-Module HPECOMCmdlets
    ```

2. **Connect with your credentials**
    ```powershell
    # Connect with SSO password-based (Okta, Entra ID, PingID - federation auto-detected) with or without MFA (push/TOTP) [v1.0.26+]
    Connect-HPEGL -Credential (Get-Credential -UserName "user@company.com") -Workspace "MyWorkspace"

    # Connect with SSO passwordless (Okta, Entra ID, PingID - push, or TOTP where supported)
    Connect-HPEGL -PasswordlessSSOEmail "user@company.com" -Workspace "MyWorkspace"

    # Connect with HPE Account
    Connect-HPEGL -Credential (Get-Credential) -Workspace "MyWorkspace"
    ```

3. **Start managing resources**
    ```powershell
      # List all devices in workspace
      Get-HPEGLDevice

      # Get servers from specific COM region
      Get-HPECOMServer -Region "eu-central"

      # Add multiple tags to devices
      Get-HPEGLDevice | Add-HPEGLDeviceTagToDevice -Tags "Environment=Production, Location=DataCenter1"

      # View subscriptions
      Get-HPEGLSubscription

      # Create a new workspace
      New-HPEGLWorkspace -Name "Development" -Type 'Standard enterprise workspace' -Street "123 Main St" -Country "United States"

      # Invite users with specific roles
      Send-HPEGLUserInvitation -Email "admin@company.com" -Role 'Workspace Administrator'

      # Monitor and manage server jobs
      Get-HPECOMJob -Region "eu-central"
      Restart-HPECOMServer -Region "eu-central" -ServerSerialNumber 'CZ12312312' -ScheduleTime (Get-Date).AddHours(6)

      # Browse available firmware bundles
      Get-HPECOMFirmwareBaseline -Region "eu-central"

      # Organize servers into groups
      Get-HPECOMGroup -Region "us-west"
      New-HPECOMGroup -Region "us-west" -Name "Production-Servers"
      Add-HPECOMServerToGroup -Region "us-west" -ServerSerialNumber "J208PP0026" -GroupName "Production-Servers"
      ```

      📦 **More Examples**: Explore the [HPE Compute Ops Management Zero Touch Automation Example](https://github.com/jullienl/HPE-COM-PowerShell-Library/blob/main/Examples/COM-Zero-Touch-Automation.ps1) script for comprehensive command reference.


4. **Disconnect when done**
    ```powershell
    Disconnect-HPEGL
    ```

### Troubleshooting & Help
```powershell
# Get detailed help for any cmdlet
Get-Help Connect-HPEGL -Full
Get-Help Set-HPEGLSSOConnection -Examples

# Enable verbose output for debugging
Connect-HPEGL -PasswordlessSSOEmail "user@company.com" -Workspace "Production" -Verbose

# List all available cmdlets
Get-Command -Module HPECOMCmdlets
```

> 💡 **Need More Help?** Check out the [blog tutorials](https://jullienl.github.io/PowerShell-library-for-HPE-GreenLake) for detailed walkthroughs and real-world examples!


[↑ Back to Top](#hpe-compute-ops-management-powershell-library)


## Requirements

- **Supported PowerShell Version**: 7 or higher. 

    > **Note**: PowerShell version 5 is not supported. 

- **Supported PowerShell Editions**: PowerShell Core version 7 or higher.

- **HPE Account requirements**: Required for direct authentication (username/password or MFA)

  ✅ **When you need it:**
  - Authenticating directly to HPE GreenLake without SSO
  - Using built-in MFA (email or authenticator app)

  ❌ **When you don't need it:**
  - Using SSO with Okta, Microsoft Entra ID, or PingIdentity
  - Your organization manages authentication through external IdP

  📝 **Create your account:**
  - Visit: https://common.cloud.hpe.com
  - Setup guide: [HPE GreenLake Cloud User Guide](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&page=GUID-497192AA-FDC2-49C5-B572-0D2F58A23745.html)


- **Roles and permissions:**
  Minimum required role to connect and view resources:
  - HPE GreenLake Workspace Observer (view-only access)
  - HPE Compute Ops Management Viewer (view-only access for each COM instance)

  Additional roles required for management operations:
  - HPE GreenLake Workspace Administrator: Required for workspace creation and management
  - HPE Compute Ops Management Administrator: Required for COM instance provisioning and management

  Note: Multiple roles can be assigned to a single user. Contact your HPE GreenLake administrator to request appropriate role assignments.


- **Workspace Type Compatibility**:

  - **Enhanced workspaces (IAMv2):** Fully supported since v1.0.25 
    - ✅ Complete feature set including new organization management, user groups, and scope-based access control (SBAC)
    - ✅ Advanced identity features: domains, SSO connections, authentication policies
    - ✅ Modern user and role management with improved security
    - ✅ All new features and functionality
    
  - **Legacy workspaces (IAMv1):** Continued support with compatibility mode
    - ✅ Core functionality remains fully operational
    - ⚠️ Some SAML SSO domain functions are deprecated (migration guidance provided)
    - ⚠️ Limited access to newer IAMv2-specific features (user groups, advanced SBAC, etc.)
    - 📖 See [Migration Guide](Build-Tools/Release%20notes/1.0.25.md#migration-guide) in release notes for updating deprecated functions 

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)

## Best Practices & Performance Considerations

### API Rate Limiting

HPE GreenLake APIs implement rate limiting to ensure fair resource allocation and system stability. While most users won't encounter these limits during normal operations, it's important to be aware of them for high-volume scenarios.

**When Rate Limits May Apply:**
- **Bulk Operations**: Processing hundreds or thousands of resources in rapid succession
- **Parallel Execution**: Running multiple scripts or PowerShell sessions simultaneously
- **High-Frequency Automation**: Scheduled tasks running every few minutes
- **Large-Scale Inventory**: Retrieving detailed information for many servers at once

**Best Practices to Avoid Rate Limiting:**

1. **Batch Your Operations**:
   ```powershell
   # Instead of individual calls in a tight loop
   $servers = Get-HPECOMServer -Region "eu-central"
   # Then process results without additional API calls
   $servers | Where-Object { $_.Model -like "*DL380*" }
   ```

2. **Add Delays for Bulk Operations**:
   ```powershell
   # For large-scale operations, add a small delay
   Get-HPECOMServer -Region "eu-central" | ForEach-Object {
       Get-HPECOMServerInventory -Region "eu-central" -Name $_.SerialNumber
       Start-Sleep -Milliseconds 100  # Small delay between calls
   }
   ```

3. **Use Filtering Parameters**: Reduce API calls by using cmdlet parameters instead of PowerShell filtering
   ```powershell
   # Good: Server-side filtering
   Get-HPECOMServer -Region "eu-central" -Model "ProLiant DL380 Gen10"
   
   # Less efficient: Client-side filtering (more API calls)
   Get-HPECOMServer -Region "eu-central" | Where-Object { $_.Model -eq "ProLiant DL380 Gen10" }
   ```

4. **Schedule Automation Wisely**: For scheduled scripts, avoid intervals shorter than 5-10 minutes unless necessary

**If You Encounter Rate Limiting:**
- Error: `429 (Too Many Requests)` or `Rate limit exceeded`
- Solution: Wait a few minutes before retrying, or implement exponential backoff in your scripts
- The library includes automatic retry logic for some transient errors

> **Note**: Rate limits vary by API endpoint and are subject to change. For specific limits, consult the [Rate limiting](https://developer.greenlake.hpe.com/docs/greenlake/guides/public/rate-limiting/rate-limiting) page on the HPE GreenLake Developer Portal.

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)

## Supported authentication methods

### Single-factor authentication with HPE Account
  - Requires an HPE Account (username and password)
  - Direct authentication using HPE Account credentials
  - Suitable for non-SSO environments or testing scenarios

### Multi-factor authentication (MFA) with HPE Account
  - **Supported MFA Methods**:
    - Time-based One-Time Password (TOTP) codes via Google Authenticator
    - Push notifications via Okta Verify mobile app
    
    > **Note**: FIDO2 security keys and biometric authenticators (Windows Hello, Touch ID) are not supported      

  - **MFA Requirements**:
    - An HPE account with MFA configured
    - Authenticator app must be installed and linked to your HPE Account
    - If your account uses only security keys or biometrics, you must enable Google Authenticator or Okta Verify in your account settings
    - When both methods are available, Okta Verify push notifications take precedence

### SAML Single Sign-On (SSO) - Passwordless and Password-based

  **New in v1.0.26**: Password-based SSO via `-Credential` is now supported alongside the existing passwordless flow. Use `-PasswordlessSSOEmail` for push/TOTP authentication, or `-Credential` with your federated email address for password-based authentication. Federation is detected automatically.
        
  - **Supported Identity Providers**:

    | Identity Provider      | Implementation                              | Status            | Push Notifications | TOTP Codes                | Number Matching  | Timeout | Cloud Environment     | Requirements                                            | Last Tested |
    |------------------------|---------------------------------------------|-------------------|--------------------|---------------------------|------------------|---------|-----------------------|---------------------------------------------------------|-------------|
    | **Okta (OIE only)**    | Okta SAML + Okta Verify                     | ✅ Fully Supported | ✅ Yes              | ✅ Yes                     | Optional         | 2 min   | All Okta regions      | **Requires OIE**<sup>1</sup><br>❌ Classic not supported | June-2026   |
    | **Microsoft Entra ID** | Entra ID SAML + Microsoft Authenticator     | ✅ Fully Supported | ✅ Yes              | ⚠️ Conditional<sup>2</sup> | Mandatory (push) | 2 min   | Commercial cloud only | -                                                       | June-2026   |
    | **PingIdentity**       | PingOne SSO (SAML) + PingID MFA<sup>3</sup> | ✅ Fully Supported | ✅ Yes              | ✅ Yes                     | Optional         | 2 min   | All PingOne regions   | **Requires a PingOne SSO environment**                  | June-2026   |
    | **PingIdentity**       | PingFederate SAML + PingID MFA              | ⚠️ Not Tested      | ✅ Expected         | ✅ Expected                | Optional         | 2 min   | All PingOne regions   | -                                                       | June-2026   |

    <br>
    
    > <a id="okta-oie-requirement"></a>**<sup>1</sup> Okta - Okta Identity Engine (OIE) required:** Okta SSO requires **Okta Identity Engine (OIE)**. **Okta Classic Engine is not supported** - the library relies on the Okta IDX API (`/idp/idx/*`), which is only available in OIE. **Check your engine:** in the Okta Admin Console, the version number in the page footer (e.g., `2025.12.0`) ends in **E** for OIE or **C** for Classic; if you're on Classic, contact your Okta administrator or Okta support to upgrade. See the [Okta Identity Engine Overview](https://support.okta.com/help/s/product-hub/oie/overview?language=en_US).
    >
    > <img src="Images/SAML_SSO_0A.png" alt="Screenshot" width="30%">

    > **<sup>2</sup> Microsoft Entra ID - TOTP support is conditional:** TOTP codes (Microsoft Authenticator one-time codes) are supported **only in password-based flows** (`-Credential`), where the password is verified first and TOTP is presented as a step-up second factor. TOTP is **not** available in the **passwordless** flow (`-PasswordlessSSOEmail`): Entra ID passwordless authentication relies exclusively on Microsoft Authenticator push notifications with mandatory number matching. If your Entra ID policy is passwordless-only, use push approval; if it is password + MFA, you may use either push or a TOTP code.

    > **<sup>3</sup> PingIdentity - use a PingOne *SSO* environment, not a PingOne *MFA* environment:** In the PingOne admin console you can create either a **PingOne SSO** environment or a standalone **PingOne MFA** environment - these are different services. This library implements the **PingOne SSO** sign-on flow (SAML federation + the PingOne sign-on policy), completing MFA through the **PingID** mobile app (push or TOTP). The standalone **PingOne MFA** service (mobile-SDK / DaVinci-orchestrated MFA) uses a different authentication flow and is **not supported**. Configure HPE GreenLake as a SAML application in a **PingOne SSO** environment and enroll users in **PingID**.

    <br>

    > ⚠️ **Important: Testing & Environment Variations**
    >
    > While this library has been tested with **Okta**, **Microsoft Entra ID**, and **PingIdentity** in standard configurations, Identity Provider implementations can vary significantly across organizations due to:
    > - Custom authentication policies and security settings
    > - Regional differences and cloud environments
    > - Organization-specific configurations and restrictions
    > - Version differences in IdP software
    >
    > If you encounter authentication issues specific to your environment:
    > - 🐛 **Report Bugs**: [Open an issue](https://github.com/jullienl/HPE-COM-PowerShell-Library/issues)
    > - 💬 **Get Help**: [GitHub Discussions](https://github.com/jullienl/HPE-COM-PowerShell-Library/discussions)
    > - 📘 **Check Guide**: [SAML SSO Configuration Tutorial](https://jullienl.github.io/Configuring-SAML-SSO-with-HPE-GreenLake-and-Passwordless-Authentication-for-HPECOMCmdlets)

 
  - **⚠️ Unsupported Identity Providers**
    - Identity Providers **not listed in the table above** (such as Google Workspace, Salesforce Identity, IBM Security Verify, Auth0, OneLogin, etc.) are **not supported** by this library.
    - **Why?** While these providers may support SAML 2.0, their authentication flows differ significantly and have not been tested or implemented in this library.
  
    - **Alternative Authentication Options:**
      1. **HPE Account**: Use direct authentication with or without MFA with Google Authenticator or Okta Verify

         ```powershell
         Connect-HPEGL -Credential (Get-Credential) -Workspace "Production"
         ```

      2. **Request Support**: [Open a feature request](https://github.com/jullienl/HPE-COM-PowerShell-Library/issues) with:
          - Your Identity Provider name and version
          - Authentication methods your organization uses
          - Your specific use case and requirements

  - **Authentication Modes**:
    - **Passwordless (push/TOTP)** via `-PasswordlessSSOEmail`: Use this parameter only when your IdP account is configured for passwordless authentication (push notifications or TOTP - no password). If the IdP requires a password, an error is returned with instructions to use `-Credential`. The parameter never prompts interactively, ensuring automation scripts do not hang.
    - **Password-based** via `-Credential`: Supported for Okta, Microsoft Entra ID, and PingIdentity. When your IdP policy requires a password, use `-Credential` with your federated email address - the password is submitted to the IdP and, if a second factor is required (step-up MFA), a push notification or TOTP challenge fires automatically. Federation is detected automatically.
    - **Password silently ignored**: If `-Credential` is used but the IdP account is passwordless-only, the password field is ignored and the normal push/TOTP flow proceeds with a warning.
    - **HPE Account password authentication remains supported** - direct authentication using HPE Account credentials (username/password) continues to work for non-SSO scenarios.

      > **HPE corporate accounts (`@hpe.com`):** HPE employee accounts are federated through HPE's internal Okta SSO, which is **passwordless**. Sign in with `-PasswordlessSSOEmail` and approve the push notification. 
      > For example: `Connect-HPEGL -PasswordlessSSOEmail "first.last@hpe.com" -Workspace "MyWorkspace"`.    
      > Using `-Credential` for an `@hpe.com` account returns a warning that a password is not required and to use `-PasswordlessSSOEmail` instead.

  - **Authentication Method Support**:

    - ✅ **Supported**: Push notifications (Microsoft Authenticator, Okta Verify, PingID) and TOTP codes
    - ❌ **Not Supported**: FIDO2 security keys, passkeys, and Windows Hello biometrics
    
      > **Recommendation**: If your account is configured only for FIDO2/passkey authentication, enable push notifications in your Identity Provider settings for PowerShell access. Push notifications with number matching meet the same phishing-resistant security standards as FIDO2

      > **Technical Reason**: FIDO2/WebAuthn requires browser-native APIs (navigator.credentials) and direct hardware access that are not available in PowerShell automation environments 

  - **SSO Prerequisites**:
    - ✅ SAML SSO configured in your HPE GreenLake workspace
    - ✅ Identity Provider configured with HPE GreenLake as a SAML 2.0 application
    - ✅ User has appropriate application access permissions
    - ✅ Domain pre-claimed in workspace (use `Get-HPEGLDomain` to verify, `Get-HPEGLSSOConnection` to check configuration)
    - ✅ **For passwordless flow** (`-PasswordlessSSOEmail`): Passwordless authentication methods enabled in your IdP (push notifications and/or TOTP)
    - ✅ **For password-based flow** (`-Credential`): User's IdP account has a password enrolled (password-only or password + MFA step-up policy)
    - ❌ **OpenID Connect (OIDC) federation is not supported**: This library only supports **SAML 2.0** SSO federation. HPE GreenLake also allows configuring workspace SSO via OIDC, but OIDC-federated workspaces cannot be used with `-PasswordlessSSOEmail` or `-Credential` SSO - sign in with native HPE account credentials instead.

  - **Quick Setup with PowerShell**: Automate the full SAML SSO configuration in your HPE GreenLake workspace - claim a domain, verify it, create the SSO connection, and apply the authentication policy - directly from PowerShell:

    ```powershell
    # 1. Claim your organization's domain (returns the DNS TXT record to publish)
    New-HPEGLDomain -Name "example.com"

    # 2. After adding the TXT record at your DNS provider, verify domain ownership
    Test-HPEGLDomain -Name "example.com"

    # 3. Create the SAML 2.0 SSO connection from your IdP metadata, with a recovery account
    $recoveryPassword = ConvertTo-SecureString "MySecurePass123!" -AsPlainText -Force
    New-HPEGLSSOConnection -Name "Okta SSO" -SAML20 `
        -MetadataSource "https://idp.example.com/federationmetadata/2007-06/federationmetadata.xml" `
        -RecoveryAccountSecurePassword $recoveryPassword `
        -RecoveryAccountContactEmail "it-admin@example.com"

    # 4. Apply the SSO authentication policy linking the domain to the connection
    New-HPEGLSSOAuthenticationPolicy -VerifiedDomainName "example.com" `
        -SSOConnectionName "Okta SSO" `
        -AuthorizationMethod "AuthorizationMode" `
        -RecoveryAccountSecurePassword $recoveryPassword `
        -RecoveryAccountContactEmail "it-admin@example.com"

    # Review the configuration
    Get-HPEGLDomain
    Get-HPEGLSSOConnection
    Get-HPEGLSSOAuthenticationPolicy
    ```

    > 💡 **Tip**: Use `Get-Help <cmdlet-name> -Examples` to see more scenarios (OIDC connections, custom SAML attribute mappings, external domains, and update/remove operations such as `Set-HPEGLSSOConnection` and `Remove-HPEGLSSOAuthenticationPolicy`).

    > ℹ️ **Authorization method and `Connect-HPEGL`:** Both authorization methods of the authentication policy are supported by the SSO sign-in flow:
    > - **`AuthorizationMode`** - roles are delivered by the IdP through the SAML `hpe_ccs_attribute`. Configure authorization mappings in your IdP so users receive their workspace roles on sign-in.
    > - **`AuthenticationOnlyMode`** - SSO is used for authentication only; roles are assigned **locally in HPE GreenLake** (manually or via SCIM). `Connect-HPEGL` works the same way in this mode, but the user must already have a role assigned in the workspace (e.g., *Workspace Observer* + a COM role) - otherwise sign-in succeeds but no workspace/role is available.

  - **Configuration Guide**:  

    > 📘 **[Complete SAML SSO Setup Guide](https://jullienl.github.io/Configuring-SAML-SSO-with-HPE-GreenLake-and-Passwordless-Authentication-for-HPECOMCmdlets)**  
    > Step-by-step tutorial for configuring SAML SSO with Okta, Microsoft Entra ID, and PingIdentity, then signing in from HPECOMCmdlets using passwordless (push/TOTP) or password-based (`-Credential`, v1.0.26+) authentication. Includes screenshots, troubleshooting tips, and best practices.

    Additional Resources:
      - 📖 [HPE GreenLake Cloud User Guide](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us) - Official HPE documentation for workspace and authentication configuration
      - 💬 [GitHub Discussions](https://github.com/jullienl/HPE-COM-PowerShell-Library/discussions) - Community support and Q&A


[↑ Back to Top](#hpe-compute-ops-management-powershell-library)

## How to Install the Module  

To install the library, use the following command to download and install the module from the official PowerShell Gallery:

```powershell
# Check PowerShell version
$PSVersionTable.PSVersion  # Should be 7.0 or higher

# Install the module
Install-Module HPECOMCmdlets

# Verify installation
Get-Module HPECOMCmdlets -ListAvailable

# View available cmdlets
Get-Command -Module HPECOMCmdlets
```

##  How to Upgrade the Module 

If you have already installed the module and need to update it to the latest version, run the following commands:

```powershell
# Step 0: Unload the module from memory (if currently loaded)
Remove-Module HPECOMCmdlets -Force -ErrorAction SilentlyContinue

# Step 1: Get the currently installed version
$latestVersion = (Get-InstalledModule HPECOMCmdlets | Sort-Object Version -Descending | Select-Object -First 1).Version

# Step 2: Install latest version
Install-Module -Name HPECOMCmdlets -Scope CurrentUser -Force -AllowClobber

# Step 3: Uninstall the old version
Uninstall-Module -Name "HPECOMCmdlets" -RequiredVersion $latestVersion

# Step 4: Verify the upgrade
Get-Module HPECOMCmdlets -ListAvailable | Select-Object Name, Version, Path
```
<br>

  > **Important Notes:**
  > - **Step 0 (Unload Module)**: Required to release file locks and clear old code from memory. Without this, Windows may prevent file updates or the old version may remain active even after installation.
  > - **-Scope CurrentUser**: Installs to your user profile (`~\Documents\PowerShell\Modules\`) without requiring administrator privileges. Omit this parameter or use `-Scope AllUsers` if you have admin rights and want to install for all users.
  > - **Version Verification**: Step 4 confirms the upgrade succeeded and shows the installation path to verify the correct version is loaded.

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)

## How to Connect to HPE GreenLake and Compute Ops Management

The `Connect-HPEGL` cmdlet establishes a connection to HPE GreenLake and all Compute Ops Management (COM) instances provisioned in your workspace. A single call provides access to:

- **HPE GreenLake platform services** - workspace management, users, subscriptions, devices, and more
- **All regional COM instances simultaneously** (e.g., eu-central, us-west, ap-northeast) via the `-Region` parameter
- **One active session** per PowerShell process, stored in `$Global:HPEGreenLakeSession`

### Session Management

Upon successful connection, `$Global:HPEGreenLakeSession` is created and contains all authentication context:

- **Session information**: Web request sessions for authentication and API operations
- **API credentials**: Temporary unified API client credentials for HPE GreenLake and COM instances
- **OAuth2 tokens**: Access token (2 h), refresh token, ID token with automatic refresh
- **Workspace details**: Workspace ID, name, and organization
- **SSO identity provider metadata**: Name and type of the SSO identity provider (when available), including the IdP tenant URL and the idpType (EntraID, Okta, or PingIdentity)
- **COM regions**: List of provisioned COM regions and their endpoints

**Token lifecycle:**
- Access tokens are valid for 2 hours; the library refreshes them automatically when they expire
- Sessions do not persist across PowerShell restarts
- Use `Disconnect-HPEGL` to explicitly revoke tokens and clean up API credentials

**View session details:**
```powershell
# Display current session
$Global:HPEGreenLakeSession

# View API credentials for connected services
$Global:HPEGreenLakeSession.apiCredentials

# Check token creation time
$Global:HPEGreenLakeSession.oauth2TokenCreation
```

**Save and restore sessions (multi-workspace workflows):**

Use `Save-HPEGLSession` and `Restore-HPEGLSession` to switch between workspaces without re-authenticating:

```powershell
# Connect to first workspace and save the session
Connect-HPEGL -PasswordlessSSOEmail "user@company.com" -Workspace "Production"
$prodSession = Save-HPEGLSession

# Switch to a second workspace
Connect-HPEGLWorkspace -Name "Development"   # fast switch - reuses existing OAuth2 tokens
$devSession = Save-HPEGLSession

# Switch back instantly - tokens are refreshed automatically
Restore-HPEGLSession -Session $prodSession

# Switch to dev again
Restore-HPEGLSession -Session $devSession
```

To handle session expiry in long-running scripts:
```powershell
try {
    Restore-HPEGLSession -Session $prodSession
}
catch {
    # Refresh token expired - fall back to full re-authentication
    Connect-HPEGL -Credential $cred -Workspace "Production" | Out-Null
    $prodSession = Save-HPEGLSession
}
```

> **💡 Tip**: For full session object documentation, use `Get-Help Connect-HPEGL -Full` and review the OUTPUTS section.

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)


### Regional COM Instance Support

When connected, use the `-Region` parameter in COM cmdlets to target a specific instance:

```powershell
# Manage servers in European COM instance
Get-HPECOMServer -Region "eu-central"

# Manage servers in US COM instance  
Get-HPECOMServer -Region "us-west"
```

### Authentication Examples

Choose the authentication method that matches your setup:

Quick jump: [Example 1](#example-1-direct-authentication-with-username-and-password) | [Example 2](#example-2-saml-sso-with-okta-push-notification-with-number-matching) | [Example 3](#example-3-saml-sso-with-microsoft-entra-id-push-notification-with-number-matching) | [Example 4](#example-4-saml-sso-with-pingidentity-push-notification) | [Example 5](#example-5-connect-without-specifying-workspace) | [Example 6](#example-6-enable-verbose-output-for-troubleshooting) | [Example 7](#example-7-connecting-to-the-pavo-pre-production-environment-optional)

> **Note:** For password-based SSO (Okta, Entra ID, PingIdentity), use `-Credential` with your federated email address. Federation is detected automatically - no additional parameters are needed.

> **New in v1.0.26:** Password-based SSO authentication is now supported for Okta, Microsoft Entra ID, and PingIdentity via `-Credential`. The `-SSOEmail` parameter has been renamed to `-PasswordlessSSOEmail` (the `-SSOEmail` alias remains fully functional for backward compatibility).

> **Important:** `-PasswordlessSSOEmail` is strictly for passwordless IdP accounts (push/TOTP only). If your IdP requires a password, use `-Credential` - using `-PasswordlessSSOEmail` for a password-based account returns an error and never prompts interactively.

| Method | Use when | Parameter | Related example |
|--------|----------|-----------|-----------------|
| HPE Account (password only) | No SSO configured; direct authentication | `-Credential` | [Example 1](#example-1-direct-authentication-with-username-and-password) |
| HPE Account + MFA | HPE Account with Okta Verify or Google Authenticator enabled | `-Credential` | [Example 1](#example-1-direct-authentication-with-username-and-password) |
| SAML SSO - Okta (passwordless) | Workspace uses Okta; account is passwordless (push/TOTP only) | `-PasswordlessSSOEmail` | [Example 2](#example-2-saml-sso-with-okta-push-notification-with-number-matching) |
| SAML SSO - Microsoft Entra ID (passwordless) | Workspace uses Entra ID; account is passwordless | `-PasswordlessSSOEmail` | [Example 3](#example-3-saml-sso-with-microsoft-entra-id-push-notification-with-number-matching) |
| SAML SSO - PingIdentity (passwordless) | Workspace uses PingIdentity; account is passwordless | `-PasswordlessSSOEmail` | [Example 4](#example-4-saml-sso-with-pingidentity-push-notification) |
| SAML SSO - Okta (password-based) | Workspace uses Okta; IdP requires a password | `-Credential` | [Example 1](#example-1-direct-authentication-with-username-and-password) |
| SAML SSO - Microsoft Entra ID (password-based) | Workspace uses Entra ID; IdP requires a password | `-Credential` | [Example 1](#example-1-direct-authentication-with-username-and-password) |
| SAML SSO - PingIdentity (password-based) | Workspace uses PingIdentity; IdP requires a password | `-Credential` | [Example 1](#example-1-direct-authentication-with-username-and-password) |
| Pavo pre-production | HPE internal testing only | `-PasswordlessSSOEmail` + `$env:HPE_COMMON_CLOUD_URL` | [Example 7](#example-7-connecting-to-the-pavo-pre-production-environment-optional) |

#### Example 1: Direct authentication with username and password

- Bypasses SSO federation and requires an HPE account

  ```powershell
  $cred = Get-Credential
  Connect-HPEGL -Credential $cred -Workspace "Production" -RemoveExistingCredentials
  ```

- The `-RemoveExistingCredentials` parameter removes all existing API credentials generated by previous connections. Use this to resolve the "maximum of 7 personal API clients" error by clearing unused credentials.

- Upon successful connection, a `$Global:HPEGreenLakeSession` object is created and displayed, containing your authentication context and connection details

  <img src="Images/SAML_SSO_0.png" alt="Screenshot" width="40%">

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)


#### Example 2: SAML SSO with Okta (push notification with number matching)

- Uses Okta SAML federation with Okta Verify push notifications
- Number matching provides phishing-resistant authentication

  ```powershell
  Connect-HPEGL -PasswordlessSSOEmail "user@company.com" -Workspace "Production"
  ```

   > **💡 Tip**: Add `-RemoveExistingCredentials` if you encounter "maximum of 7 personal API clients" error. This clears old API credentials from previous sessions.
  
- During the authentication process, a verification number (e.g., 59) will be displayed in the PowerShell console

  <img src="Images/SAML_SSO_4.png" alt="Screenshot" width="40%">   

- Approve the push notification sent to Okta Verify by tapping the matching number on your mobile device.

  <img src="Images/SAML_SSO_3.png" alt="Screenshot" width="12%">

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)


#### Example 3: SAML SSO with Microsoft Entra ID (push notification with number matching)
- Uses Microsoft Entra ID SAML federation with Microsoft Authenticator
- Number matching is mandatory and provides phishing-resistant authentication

  ```powershell
  Connect-HPEGL -PasswordlessSSOEmail "user@company.com" -Workspace "Production"
  ```

   > **💡 Tip**: Add `-RemoveExistingCredentials` if you encounter "maximum of 7 personal API clients" error. This clears old API credentials from previous sessions.

- During the authentication process, a verification number (e.g., 59) will be displayed in the PowerShell console

  <img src="Images/SAML_SSO_1.png" alt="Screenshot" width="40%">

- Approve the push notification sent to Microsoft Authenticator by typing the matching number on your mobile device. 

  <img src="Images/SAML_SSO_2.png" alt="Screenshot" width="12%">

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)


#### Example 4: SAML SSO with PingIdentity (push notification)
- Uses PingIdentity SAML federation with PingID mobile app
- Supports both push notifications and TOTP codes for flexible authentication

  ```powershell
  Connect-HPEGL -PasswordlessSSOEmail "user@company.com" -Workspace "Production"
  ```

   > **💡 Tip**: Add `-RemoveExistingCredentials` if you encounter "maximum of 7 personal API clients" error. This clears old API credentials from previous sessions.

- During the authentication process, a push notification will be sent to your PingID mobile app

  <img src="Images/SAML_SSO_5.png" alt="Screenshot" width="40%">

- Approve the push notification on your mobile device to complete authentication

  <img src="Images/SAML_SSO_6.png" alt="Screenshot" width="12%">

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)


#### Example 5: Connect without specifying workspace 

- If you have not yet created any workspace, you must omit the `-Workspace` parameter. 

  ```powershell
  Connect-HPEGL -PasswordlessSSOEmail "user@company.com"
  ```

- After successful authentication, you can create a new workspace using `New-HPEGLWorkspace`.

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)

#### Example 6: Enable verbose output for troubleshooting

- Use the `-Verbose` parameter to display detailed authentication flow information for debugging connection issues

  ```powershell
  Connect-HPEGL -PasswordlessSSOEmail "user@company.com" -Workspace "Production" -Verbose
  ```

- The verbose output includes:
  - SAML authentication steps and redirects
  - Identity Provider detection and configuration
  - MFA method selection and status
  - API token generation and validation
  - Workspace connection confirmation

- Useful for diagnosing authentication failures, SSO configuration issues, or timeout problems


[↑ Back to Top](#hpe-compute-ops-management-powershell-library)


#### Example 7: Connecting to the Pavo Pre-Production Environment (Optional)

> **⚠️ Note**: This section is for HPE internal developers and partners only. The only supported non-production environment is **Pavo** (HPE's internal pre-production platform).

By default, `Connect-HPEGL` connects to the production HPE GreenLake environment. To connect to Pavo, set the `HPE_COMMON_CLOUD_URL` environment variable before calling `Connect-HPEGL`. Setting this single variable is all that is required - all API endpoints, authentication URLs, and credentials are auto-configured from Pavo's `settings.json`.

**Environment Variables:**

| Variable | Required | Description | Production Default |
|----------|----------|-------------|-------------------|
| `HPE_COMMON_CLOUD_URL` | **Required** | Entry point URL - its `/settings.json` drives all other endpoint auto-configuration | `https://common.cloud.hpe.com` |
| `HPE_AUTH_URL` | Optional | Overrides the auth endpoint used for the pre-connect TCP connectivity check only | `https://auth.hpe.com` |
| `HPE_SSO_URL` | Optional | Fallback SSO URL when it cannot be derived from settings (rarely needed for Pavo) | `https://sso.common.cloud.hpe.com` |

**Connect to Pavo:**

```powershell
# Set the Pavo entry-point URL - all other endpoints are auto-configured
$env:HPE_COMMON_CLOUD_URL = "https://pavo.common.cloud.hpe.com"

# Connect using SSO (typically with your @hpe.com corporate account)
Connect-HPEGL -PasswordlessSSOEmail "developer@hpe.com" -Workspace "MyDevWorkspace"
```

**Return to production (clear the env var):**

```powershell
Remove-Item Env:\HPE_COMMON_CLOUD_URL -ErrorAction SilentlyContinue

# Next connection will use production endpoints
Connect-HPEGL -PasswordlessSSOEmail "user@company.com" -Workspace "Production"
```

**Important Notes:**
- ⚠️ Pavo data, user accounts, and configurations are separate from production
- ⚠️ Always clear `HPE_COMMON_CLOUD_URL` before switching back to production - if left set, all subsequent `Connect-HPEGL` calls will target Pavo
- 💡 These environment variables persist only for the current PowerShell session unless you set them at the system level

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)


### Global Variables Reference

The module automatically maintains the following global variables throughout your session:

| Variable | Purpose | When Available |
|----------|---------|----------------|
| `$Global:HPEGreenLakeSession` | All authentication tokens & session state | After `Connect-HPEGL` |
| `$Global:HPEGLSchemaMetadata` | Countries (247) & Timezones (~100) | Module import |
| `$Global:HPESupportedLanguages` | Language options for user preferences | Module import |
| `$Global:HPECOMRegions` | Available COM regions | After workspace connection |
| `$Global:HPECOMjobtemplatesUris` | Job template mappings | After first COM operation |
| `$Global:HPECOMCmdletsModuleVersion` | Installed module version | Module import |
| `$Global:HPECOMLastJobResult` | Last job cmdlet result (for post-execution inspection) | After any job cmdlet |
| `$Global:HPECOMInvokeReturnData` | Last API response (for debugging) | After any API call |

**`$Global:HPECOMLastJobResult`** is particularly useful when a job cmdlet output is truncated at the console - the full result (untruncated `message`, `jobUri`, `details`, etc.) is always accessible afterward:

```powershell
# Run a job cmdlet (output may be truncated in the console)
Invoke-HPECOMServerFirmwareDownload -Region eu-central -Name myserver -FirmwareBaselineReleaseVersion "2025.11.01.00"

# Inspect the full result at any time after
$Global:HPECOMLastJobResult.message
$Global:HPECOMLastJobResult.jobUri
$Global:HPECOMLastJobResult | Format-List
```

All session-scoped variables (`HPEGreenLakeSession`, `HPECOMInvokeReturnData`, `HPECOMLastJobResult`, etc.) are automatically cleared when you run `Disconnect-HPEGL`.

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)


## Onboarding Servers to Compute Ops Management

The library offers two complementary ways to connect server iLOs to Compute Ops Management. They are not competing - pick the one that matches your environment:

| | `Connect-HPEGLDeviceComputeiLOtoCOM` | `Connect-HPECOMSecureGatewayDiscoveredServer` *(v1.0.26+)* |
|---|---|---|
| **Best for** | Any connection type (direct / web proxy / Secure Gateway), migrations, fine-grained control | Bulk onboarding of every iLO **behind an HPE Secure Gateway** |
| **Input** | Known iLO IP(s) + credential | Discovery results piped from `Get-HPECOMSecureGatewayServerDiscovery` |
| **Connection type** | Direct, web proxy, or Secure Gateway | Secure Gateway only |
| **Activation key** | You generate it (`-ActivationKeyfromCOM`) | **Auto-generated** by COM - none needed |
| **iLO firmware update** | ❌ Not performed - you must pre-update the iLO to the minimum version (the cmdlet validates and refuses if too low) | ✅ **Auto-updated** by the gateway when discovery reports `iLOUpdateRequired = Yes` |
| **iLO DNS configuration** | ❌ Not configured - iLO must already have DNS | ✅ Optional via `-Dns` |
| **iLO NTP configuration** | ❌ Not configured - iLO must already have NTP | ✅ Optional via `-Ntp` |
| **Subscription assignment** | ❌ Separate step (auto-subscription or `Add-HPEGLSubscriptionToDevice`) | ✅ Inline via `-SubscriptionKey` |
| **Location / tags / contact** | ❌ Separate steps (`Set-HPEGLDeviceLocation`, `Add-HPEGLDeviceTagToDevice`, `Set-HPEGLDeviceServiceDeliveryContact`) | ✅ Inline via `-LocationName` / `-Tags` / `-ServiceDeliveryContact` |
| **Granularity** | One iLO per call | One batch job per Secure Gateway |
| **Network discovery** | ❌ No - you must already know the IPs | ✅ **Yes** - finds iLOs on the gateway's subnet |
| **`-WhatIf` preview** | ✅ Yes (rich per-iLO report) | ✅ Yes |

> **In short:** `Connect-HPECOMSecureGatewayDiscoveredServer` performs the full setup (firmware update, DNS/NTP, subscription, location, tags, contact) in a single batch call, but only for iLOs behind a Secure Gateway. `Connect-HPEGLDeviceComputeiLOtoCOM` connects any iLO over any path with fine-grained control, but the iLO must already meet the minimum firmware version and have DNS/NTP set, and post-onboarding configuration (subscription, location, tags, contact) is done with the dedicated `Set-HPEGL*` cmdlets.


> 🛡️ **Prefer a ready-to-run script?** The [Bulk iLO Onboarding to Compute Ops Management](https://github.com/jullienl/HPE-Compute-Ops-Management/blob/main/PowerShell/Onboarding/Prepare-and-Connect-iLOs-to-COM-v2.ps1) script wraps `Connect-HPEGLDeviceComputeiLOtoCOM` and automates everything the cmdlet does not do on its own - iLO DNS/SNTP configuration, firmware-compliance updates, activation-key generation, and location/tag assignment - driven from a CSV file with a `-Check` pre-flight mode and CSV status reporting. It is the turnkey equivalent of the Secure Gateway batch flow for estates that connect directly or through a web proxy.

**Universal / precision path** - connect a single iLO (any connection type):

```powershell
$iLO_credential = Get-Credential
$ActivationKey  = New-HPECOMServerActivationKey -Region eu-central

Connect-HPEGLDeviceComputeiLOtoCOM -IloIP "192.168.0.21" -IloCredential $iLO_credential `
    -ActivationKeyfromCOM $ActivationKey -SkipCertificateValidation
```

**Secure Gateway path** - discover and onboard an entire estate behind a Secure Gateway in one batch job (no activation key needed, iLO firmware updated automatically where required):

```powershell
$iLO_credential = Get-Credential

# 1. Discover the iLOs reachable through the Secure Gateway
Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lab"

# 2. Onboard every discovered server (firmware compliance handled automatically)
Get-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lab" |
    Connect-HPECOMSecureGatewayDiscoveredServer -IloCredential $iLO_credential
```

> 🛡️ **Prefer a ready-to-run script for the Secure Gateway path?** The [Discover and Onboard iLOs via Secure Gateway](https://github.com/jullienl/HPE-Compute-Ops-Management/blob/main/PowerShell/Onboarding/Discover-and-Onboard-iLOs-via-SecureGateway.ps1) script wraps the full `Invoke-` → `Get-` → `Connect-HPECOMSecureGatewayDiscoveredServer` workflow into a single, production-ready run: HPE GreenLake authentication, COM instance / Secure Gateway / subscription / location validation, a `-Check` pre-flight triage table (Ready / Needs firmware update / Skipped), unattended onboarding with optional DNS, NTP, location, tags and service-delivery contact, shared **or** per-iLO credentials (from a CSV keyed by IP), and a CSV status report. Because the Secure Gateway discovers the iLOs and updates their firmware server-side, it needs **no CSV of IP addresses and no local firmware staging** - it is the Secure-Gateway-native counterpart of the Bulk iLO Onboarding script above.

> 💡 Add `-WhatIf` to either cmdlet to preview every action without changing anything. Both support full automation - see the [Zero Touch Automation Example](https://github.com/jullienl/HPE-COM-PowerShell-Library/blob/main/Examples/COM-Zero-Touch-Automation.ps1).

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)


## Support

### Community Support

This is a **community-supported library** maintained by Lionel Jullien (HPE employee). It is not an official HPE product and is not covered by HPE's commercial support agreements.

**Getting Help:**

- **🐛 Bug Reports & Feature Requests**: Open a [new issue](https://github.com/jullienl/HPE-COM-PowerShell-Library/issues) on the GitHub issue tracker
- **💬 Questions & Discussions**: Join our [GitHub Discussions](https://github.com/jullienl/HPE-COM-PowerShell-Library/discussions) for general questions, tips, and community support
- **📘 Tutorials & Guides**: Visit my blog for detailed walkthroughs: [PowerShell Library for HPE Compute Ops Management](https://jullienl.github.io/PowerShell-library-for-HPE-GreenLake)
- **📖 Documentation**: Use `Get-Help <cmdlet-name> -Full` for comprehensive cmdlet documentation

**Response Time:**
- Community support is provided on a best-effort basis
- Issues are typically reviewed within 1-3 business days
- Complex issues may require additional time for investigation

**Contributing:**
- Community contributions are welcome! See the repository for contribution guidelines
- Share your scripts and use cases in GitHub Discussions


### Official HPE Support

For questions about:
- **HPE GreenLake Platform**: Contact [HPE Support](https://support.hpe.com) or consult the [HPE GreenLake Cloud User Guide](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us)
- **Compute Ops Management**: Refer to the [HPE Compute Ops Management User Guide](https://www.hpe.com/info/com-ug)
- **API Documentation**: Visit the [HPE GreenLake Developer Portal](https://developer.greenlake.hpe.com/)

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)

## Common Issues and Solutions

### "Maximum of 7 personal API clients exceeded"

**Error Message**: Failed to create API client: Maximum number of personal API clients (7) exceeded.

**Cause**: HPE GreenLake limits each user to 7 active API credentials. Old sessions from previous connections accumulate over time if not properly cleaned up.

**Solutions**:

1. **Use `-RemoveExistingCredentials` parameter** (Recommended):
   ```powershell
   # For direct authentication
   Connect-HPEGL -Credential $cred -Workspace "Production" -RemoveExistingCredentials
   
   # For SSO authentication
   Connect-HPEGL -PasswordlessSSOEmail "user@company.com" -Workspace "Production" -RemoveExistingCredentials
   ```
   This automatically removes old API credentials before creating a new one.

2. **Manual cleanup** (if needed):
   - Log into [HPE GreenLake Common Cloud Console](https://common.cloud.hpe.com)
   - Navigate to **Manage Account → API Credentials**
   - Delete unused API clients manually
   - Look for credentials with names like "PS_Library_Temp_Credential" from previous sessions

**Prevention**: 
- Always use `Disconnect-HPEGL` when finished to properly clean up credentials
- Include `-RemoveExistingCredentials` in automation scripts to prevent accumulation
- Regularly audit and remove unused API credentials from your account


### "SSO configuration issue detected" or "Domain not configured for SSO"

**Error Message**: Authentication failed: SSO configuration issue detected. The domain for 'user@domain.com' is not configured for SSO or the SSO setup is incomplete.

**Cause**: The email domain is not properly configured for SSO in HPE GreenLake, or the SSO federation setup is incomplete.

**Solutions**:
1. **Verify Domain Pre-Claim**:
   - Log into HPE GreenLake Common Cloud Console as a Workspace Administrator
   - Navigate to **Manage Workspace → Domains**
   - Confirm your email domain (e.g., `@company.com`) is listed and claimed (verified)
   
2. **Verify SSO Configuration**:
   - Ensure SAML SSO is configured for your workspace
   - Navigate to **Manage Workspace → SSO configuration → Authentication policy**
   - Confirm the Identity Provider connection is correct
   - Test SSO authentication in a browser first before using PowerShell
   
3. **Check Email Domain**:
   - Verify you're using the correct email address associated with your SSO domain
   - Ensure the domain matches the one configured in HPE GreenLake (e.g., `user@company.com` not `user@personal.com`)
   
4. **Contact Administrator**:
  - If the domain is not claimed, your Workspace Administrator must:
    - Pre-claim the domain in **Manage Workspace → Domains**
    - Complete SAML SSO setup following the **[Configuring SAML SSO with HPE GreenLake and Passwordless Authentication](https://jullienl.github.io/Configuring-SAML-SSO-with-HPE-GreenLake-and-Passwordless-Authentication-for-HPECOMCmdlets)** guide
    - Refer to the [HPE GreenLake Cloud User Guide](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us) for additional configuration details

**Note**: This error occurs before reaching your Identity Provider, indicating a configuration issue at the HPE GreenLake level, not with Okta/Entra ID/PingIdentity.


### "Timeout! MFA push notification was not approved"

**Error Messages**:
- `Timeout! Microsoft Authenticator push notification was not approved within 2 minutes`
- `Timeout! Okta Verify push notification was not approved within 2 minutes`
- `Timeout! PingID push notification was not approved within 2 minutes`

**Cause**: Authentication timeout while waiting for user to approve the push notification.

**Solutions**:
- Approve the push notification within the 2-minute timeout period
- Ensure your mobile device has an active internet connection
- Verify your authenticator app is open and signed in
- Use a TOTP code as an alternative (available for Okta and PingIdentity)

### "Microsoft Authenticator push notification was denied"

**Error Message**: Microsoft Authenticator push notification was denied. The user either clicked 'It's not me' or entered an invalid number.

**Cause**: User rejected the authentication request or entered an incorrect verification number.

**Solutions**:
- Re-run the authentication command and approve the request
- For Microsoft Entra ID: Carefully enter the exact number displayed in PowerShell
- Confirm the authentication request is legitimate before approving

### "Authenticator not enrolled" (General Guidance)

**Typical Scenarios**:
- Okta: "Okta Verify authenticator not found"
- PingIdentity: PingID not properly enrolled
- Microsoft Entra ID: Passwordless phone sign-in not configured

**Cause**: Required MFA method is not enrolled for the user account.

**Solutions**:
- Enroll in your organization's supported authenticator: Okta Verify, Microsoft Authenticator, or PingID
- For Microsoft Entra ID: Enable passwordless phone sign-in (standard MFA enrollment is insufficient)
- Configure enrollment through your Identity Provider's self-service portal
- Refer to the **[Configuring SAML SSO with HPE GreenLake and Passwordless Authentication](https://jullienl.github.io/Configuring-SAML-SSO-with-HPE-GreenLake-and-Passwordless-Authentication-for-HPECOMCmdlets)** guide

### "Configuration changes not propagating" (General Guidance)

**Cause**: Identity Provider configuration changes require time to propagate across systems.

**Solutions**:
- Allow 15-30 minutes for configuration changes to propagate across all systems
- Clear cached authentication sessions in your browser and authenticator apps
- Retry authentication after the propagation period

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)


### Identity Provider-Specific Issues

#### Okta Issues

**"Okta Verify authenticator not found"**
- **Error Message**: `Okta Verify authenticator not found. For Okta setup prerequisites, see: [setup guide]`
- **Cause**: Okta Verify not enrolled or not configured in your Okta tenant
- **Solution**: 
  - Install Okta Verify from your app store
  - Enroll through your Okta self-service portal
  - Contact your IT administrator if the app isn't available

**"Multi-factor authentication (TOTP + additional factor) is not supported"**
- **Error Message**: `Multi-factor authentication (TOTP + additional factor) is not supported. Please configure Okta to use TOTP alone.`
- **Cause**: Your Okta policy requires TOTP + password (multi-factor)
- **Solution**: Configure Okta policy to use TOTP alone without additional factors

**"Multi-factor authentication (Push + additional factor) is not supported"**
- **Error Message**: `Multi-factor authentication (Push + additional factor) is not supported.`
- **Cause**: Your Okta policy requires push + password (multi-factor)
- **Solution**: Configure Okta policy to use push alone without additional factors

#### Microsoft Entra ID Issues

**"Microsoft Authenticator passwordless sign-in is not fully configured"**
- **Error Message**: `Microsoft Authenticator passwordless sign-in is not fully configured. Please wait a few minutes for configuration changes to propagate.`
- **Cause**: Passwordless phone sign-in not fully configured or changes still propagating
- **Solution**: 
  - Wait 15-30 minutes after enrolling passwordless sign-in
  - Verify enrollment at https://mysignins.microsoft.com
  - Ensure "Passwordless sign-in" is enabled (not just standard MFA)
  - Set Microsoft Authenticator as default sign-in method at https://aka.ms/mysecurityinfo

**"AADSTS50012: Invalid client secret is provided"**
- **Note**: This is a Microsoft Entra ID service error, not generated by the library
- **Cause**: Invalid credentials or client secret mismatch. In a passwordless flow this error should not occur. In a password-based flow (`-Credential`) it indicates an incorrect password or an Entra ID application configuration issue.
- **Solution**: Verify the password is correct. If using `-PasswordlessSSOEmail` (passwordless flow), report this as a bug.

#### PingIdentity Issues

**"PingID not configured or enrolled"**
- **Typical Scenarios**: 
  - PingID app not installed or not enrolled
  - User not assigned to PingID in PingOne
  - PingID authentication policy not configured
- **Cause**: PingID not properly set up for the user account
- **Solution**:
  - Install PingID mobile app from your app store
  - Complete PingID enrollment through your organization's portal
  - Verify PingID enrollment through PingOne portal
  - Confirm your organization's PingOne region (NA/EU/APAC/CA)
  - Ensure PingID app is up to date
  - Contact your IT administrator if enrollment is not available


[↑ Back to Top](#hpe-compute-ops-management-powershell-library)

## Telemetry

The HPECOMCmdlets module can collect anonymous usage data to help improve the library. **Telemetry is OFF by default (opt-in)** — nothing is collected or sent unless you explicitly opt in by running `Enable-HPECOMDataCollection`. No directly identifying data (such as names, email addresses, credentials, IP addresses, hostnames, server names, or workspace names) is ever collected.

### What is collected

After each successful `Connect-HPEGL` call (when you have opted in), the following non-PII (non-Personally Identifiable Information) fields are sent to HPE:

| Field | Description |
|---|---|
| `module_name` | Module identifier - always `HPECOMCmdlets` |
| `module_version` | HPECOMCmdlets version |
| `ps_version` | PowerShell version |
| `ps_host` | PowerShell host application (e.g., `ConsoleHost`, `Visual Studio Code Host`) |
| `os_platform` | Operating system platform (`Win32NT`, `Unix`) |
| `os_version` | OS version string (e.g., `Microsoft Windows NT 10.0.26100.0`) |
| `auth_method` | Authentication method used: `HPEAccount`, `SSO-Okta`, `SSO-EntraID`, `SSO-PingIdentity`, `SSO-OktaHPEInternal`, `SSO-HPEInternal`, `SSO-Okta-Password`, `SSO-EntraID-Password`, `SSO-PingIdentity-Password` |
| `workspace_count` | Number of workspaces the user has access to |
| `workspace_has_com` | Whether the workspace has any COM regions configured |
| `workspace_specified` | Whether `-Workspace` was supplied at connect time |
| `com_regions` | Comma-separated list of active COM regions (e.g., `eu-central,us-west`) |
| `connect_duration_s` | Total connection time in seconds |
| `mfa_required` | Whether an MFA challenge was issued; present for HPEAccount and password-based SSO (`-Credential`); omitted for passwordless SSO (`-PasswordlessSSOEmail`) |
| `no_progress` | Whether `-NoProgress` switch was used (proxy for scripted/automated usage) |
| `is_ci` | Whether a CI/CD environment variable was detected (GitHub Actions, Azure DevOps, Jenkins, GitLab, CircleCI, or any environment where `$env:CI` is set) |
| `proxy_detected` | Whether a system proxy is configured |
| `reconnect_count` | How many times `Connect-HPEGL` has been called in the current PS session |
| `timezone` | IANA time zone ID, normalized to the same format on every OS (e.g., `Europe/Paris`) |
| `language` | UI culture (e.g., `en-US`) |
| `environment` | Which platform the connection targeted: `Production` or `Pavo` |
| `anon_id` | Anonymous, stable per-install identifier - a random GUID generated once and stored locally (`~/.config/HPECOMCmdlets/install-id`). It is **not** derived from your machine name, user name, or any other identifying attribute, so it is opaque and cannot be reversed to a person or device. Used only to count distinct installations |
| `session_id` | Random GUID generated per connect call, used only for deduplication - never stored or linked to any identity |

Data is transmitted once per `Connect-HPEGL` call over HTTPS to Azure Application Insights. A random, non-linked session ID is included solely for deduplication.

### What is collected when a connection is rejected

When an SSO sign-in is deliberately rejected (for example, an unsupported identity federation type, a wrong password, or an MFA challenge that is denied or times out), a separate event is sent so these issues can be diagnosed and prioritized. This event carries the same non-PII baseline fields listed above (such as `module_version`, `os_platform`, `environment`, `anon_id`), plus two failure-attribution fields:

| Field | Description |
|---|---|
| `failure_reason` | A fixed enum describing why the attempt was rejected - never free-form text or PII. One of: `oidc-unsupported`, `bad-credentials`, `mfa-denied`, `mfa-timeout`, `mfa-code-rejected`, `mfa-unavailable`, `totp-required`, `saml-parse-error`, `idp-error` |
| `failure_stage` | The stage of the sign-in flow where the rejection occurred: `password`, `mfa`, `saml`, or `idp` |
| `idp_vendor` | Present only for `oidc-unsupported` rejections. A fixed vendor enum identifying which identity provider the workspace federates with via the unsupported OIDC flow - classified to a vendor **name only**, never the raw host, tenant id, or org slug. One of: `EntraID`, `Okta`, `PingIdentity`, `ForgeRock`, `Google`, `OneLogin`, `Auth0`, `ADFS`, `IBM`, `Oracle`, `SailPoint`, `CyberArk`, `Thales`, `Amazon`, `Other` |

The `failure_reason` value is derived **only** from the module's own fixed English status messages, so no usernames, server names, or raw error details are ever transmitted. The `idp_vendor` value is classified to one of the fixed vendor names above - the identity provider's raw host, tenant id, and org slug are never sent. Rejection events are sent under a separate event name and never affect the connection, duration, or distinct-user metrics. The same opt-out below disables both successful-connection and rejection telemetry.

### Sample of the data collected

A single successful-connection event looks like this (all values are examples; no PII is present):

```json
{
  "name": "HPECOMCmdlets.Connect",
  "properties": {
    "module_name": "HPECOMCmdlets",
    "module_version": "1.0.26",
    "ps_version": "7.4.6",
    "ps_host": "ConsoleHost",
    "os_platform": "Win32NT",
    "os_version": "Microsoft Windows NT 10.0.26100.0",
    "auth_method": "SSO-Okta",
    "workspace_count": "3",
    "workspace_has_com": "true",
    "workspace_specified": "true",
    "com_regions": "eu-central,us-west",
    "connect_duration_s": "6.42",
    "mfa_required": "true",
    "no_progress": "false",
    "is_ci": "false",
    "proxy_detected": "false",
    "reconnect_count": "1",
    "timezone": "Europe/Paris",
    "language": "en-US",
    "environment": "Production",
    "anon_id": "a1b2c3d4e5f60718",
    "session_id": "7f3c1e9a-2b4d-4c6e-9a1f-0d8e5b2c7a14"
  }
}
```

A rejected sign-in event (`HPECOMCmdlets.ConnectRejected`) carries the same baseline fields plus the failure-attribution fields, for example:

```json
{
  "name": "HPECOMCmdlets.ConnectRejected",
  "properties": {
    "module_version": "1.0.26",
    "os_platform": "Win32NT",
    "environment": "Production",
    "anon_id": "a1b2c3d4e5f60718",
    "failure_reason": "oidc-unsupported",
    "failure_stage": "idp",
    "idp_vendor": "EntraID"
  }
}
```

### First-run notice

Until you make a choice, a short invitation notice is displayed (shown at most three times, then no longer):

```
  HPECOMCmdlets is free and community-maintained. The best way to give back? Opt in to anonymous
  usage data - it's the only insight we get into what to prioritize, test, and fix. 
  No identifying data is ever collected, it's off by default, and you can opt out anytime.
  Enable data collection (thank you!): Enable-HPECOMDataCollection
  Full transparency on what's shared:  https://github.com/jullienl/HPE-COM-PowerShell-Library#telemetry
  (This reminder will be shown 3 more times, then no longer.)
```

### Opt in

Telemetry is OFF by default. To opt in:

**Permanently** - persists across all sessions on this machine:

```powershell
Enable-HPECOMDataCollection
```

**Session only** - applies only to the current PowerShell session:

```powershell
$env:HPE_COM_ENABLE_TELEMETRY = '1'
```

To opt back out after opting in:

```powershell
Disable-HPECOMDataCollection
```

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)

## Disclaimer

Please note that the HPE GreenLake APIs are subject to change. Such changes can impact the functionality of this library. We recommend keeping the library updated to the latest version to ensure compatibility with the latest API changes.


## Additional Resources

🔗 [PowerShell Gallery](https://www.powershellgallery.com/packages/HPECOMCmdlets)

* [HPE GreenLake Cloud User Guide](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us)
* [HPE Compute Ops Management User Guide](https://www.hpe.com/info/com-ug)
* [HPE GreenLake Developer Portal](https://developer.greenlake.hpe.com/)


<!-- markdown variables links -->

[GL-master-psgallery-badge]: https://img.shields.io/powershellgallery/dt/HPECOMCmdlets?label=PSGallery
[GL-master-psgallery-link]: https://www.powershellgallery.com/packages/HPECOMCmdlets


<!-- Image Assets -->
<!-- All screenshot images are stored in /Images directory relative to this README
     Required images for SSO authentication examples:
     - SAML_SSO_0.png: HPEGreenLakeSession object display
     - SAML_SSO_1.png: Microsoft Entra ID number matching console
     - SAML_SSO_2.png: Microsoft Authenticator mobile app
     - SAML_SSO_3.png: Okta Verify mobile app
     - SAML_SSO_4.png: Okta number matching console
     - SAML_SSO_5.png: PingID authentication console
     - SAML_SSO_6.png: PingID mobile app
     
     Note: Images use relative paths (Images/filename.png) for local viewing.
     For GitHub Pages or external hosting, update paths accordingly.
-->


<!-- MISC DO NOT TOUCH -->
[new-issue-badge-url]: https://img.shields.io/badge/issues-new-yellowgreen?style=flat&logo=github
[new-issue-link]: https://github.com/jullienl/HPE-COM-PowerShell-library/issues
[github-chat-badge-url]: https://img.shields.io/badge/chat-on%20github%20discussions-green?style=flat&logo=gitter
[github-chat-link]: https://github.com/jullienl/HPE-COM-PowerShell-library/discussions


## License

This library is provided under the **MIT License**. 

📄 See the [LICENSE](LICENSE) file in this repository for the complete license text.

**Key Points:**
- ✅ Free to use, modify, and distribute
- ✅ Commercial and private use allowed
- ✅ No warranty provided (use at your own risk)
- ✅ Attribution required when redistributing

[↑ Back to Top](#hpe-compute-ops-management-powershell-library)
