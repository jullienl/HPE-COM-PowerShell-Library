<meta name="google-site-verification" content="ekN4eYyUb3noZEqgRg8BWMBhAzrWSCuNkvYByWGRGKk" />

# HPE Compute Ops Management PowerShell Library 

The HPE Compute Ops Management PowerShell library provides a set of cmdlets to manage and automate your HPE GreenLake environment. This library allows users to interact with HPE GreenLake and Compute Ops Management services directly from the PowerShell command line, enabling seamless integration into your existing automation workflows.

Development is ongoing, and the library will be continuously updated to support new features as they are released by HPE.


## Key Features

This library provides a variety of key features for managing HPE GreenLake and Compute Ops Management. Here are the main features:

- **Authentication**: Establish secure connections to HPE GreenLake using Single Sign-On (SSO) or single/multi-factor authentication. Whether you have an existing workspace or not, the library supports flexible authentication methods to suit your needs.
- **Workspace Management**: Create and manage HPE GreenLake workspaces.
- **Session Tracking**: Automatically track sessions with the global session tracker `$HPEGreenLakeSession`.
- **User Management**: Invite and manage users within your HPE GreenLake environment, assign roles.
- **Resource Management**: Manage resources such as servers, storage, and networking within your HPE GreenLake environment.
- **Service Provisioning**: Provision services like Compute Ops Management, manage service roles and subscriptions.
- **Device Management**: Add devices individually or in bulk using CSV files, manage device subscriptions and auto-subscriptions, set device locations and connect devices to services.
- **Server configuration Management**: Create and apply BIOS, storage, OS, and firmware settings. Manager group and apply configurations to groups of servers.
- **Security and Compliance**: Manage iLO security settings and run inventory and compliance checks.
- **Job Scheduling and Execution**: Schedule and execute various tasks like firmware updates, OS installations, and sustainability reports.
- **Notification and Integration**: Enable email notifications for service events and summaries, integrate with external services like ServiceNow.
- **Appliance Management**: Add HPE OneView and Secure Gateway appliances, upgrade HPE OneView appliances.
- **Monitoring and Alerts**: Monitor alerts for your resources to ensure optimal performance and uptime.
- **Reporting**: Generate detailed reports on resource usage, performance, and other metrics.
- **Automation**: Automate repetitive tasks and workflows using PowerShell scripts and cmdlets.
- **Integration**: Seamlessly integrate with other tools and platforms using REST APIs and webhooks.
- **Security**: Implement security best practices and manage access control for your HPE GreenLake environment.

These features collectively provide a comprehensive set of cmdlets to manage various aspects of your HPE GreenLake environment and any existing Compute Ops Management service instances. 

For a complete list of cmdlets and their detailed usage, refer to the module's help documentation using the `Get-Help` cmdlet.


## Latest release

1.0.12 |
------------ |
[![PS Gallery][GL-master-psgallery-badge]][GL-master-psgallery-link] |


## Requirements

- **Supported PowerShell Version**: 7 or higher. 

    > **Note**: PowerShell version 5 is no longer supported. 

- **Supported PowerShell Editions**: PowerShell Core version 7 or higher.

    > **Note**: PowerShell Core is cross-platform and compatible with Windows, macOS, and Linux. 

    > **Note**: PowerShell Desktop (Windows PowerShell 5.1) is not supported.

- **HPE Account**: An HPE Account is necessary to connect to the HPE GreenLake platform and any Compute Ops Management services.
     
    > **Note**: If you do not have an HPE Account, you can create one [here](https://common.cloud.hpe.com). To learn how to create an HPE account, see [Getting started with HPE GreenLake](https://support.hpe.com/hpesc/public/docDisplay?docId=a001.0.122en_us&page=GUID-497192AA-FDC2-49C5-B572-0D2F58A23745.html)

    > **Note**: To interact with an HPE GreenLake workspace and a Compute Ops Management instance using this library, you must have at least the ***Observer*** role for both ***HPE GreenLake Platform*** and ***Compute Ops Management*** service managers. This role grants view-only privileges. For modification capabilities, you need either the ***Operator*** (view and edit privileges) or the ***Administrator*** (view, edit, and delete privileges) role. Alternatively, you can create a custom role that meets your specific access requirements.

- **Supported authentication methodes**:
    - **Single-factor** authentication.
    - **Multi-factor** authentication (MFA) using **Google Authenticator** or **Okta Verify**. 

        > **Note**: To use MFA, ensure that the **Okta Verify** or **Google Authenticator** app is installed on your **mobile device** and properly linked to your account before initiating the connection process.   
        > - MFA with security keys or biometric authenticators is not supported. 
        >   - If your HPE GreenLake account is configured to use only security keys or biometric authenticators for MFA, you must enable either Google Authenticator or Okta Verify in your account settings to use this library.
        > - For accounts with Google Authenticator enabled, you will be prompted to enter the verification code. 
        > - For accounts with Okta Verify enabled, you will need to approve the push notification on your phone.
        > - If both Google Authenticator and Okta Verify are enabled, the library defaults to using Okta Verify push notifications.  

    - **SAML Single Sign-On** (SSO) but exclusively with **Okta**. 
        > **Note**: To use SSO, ensure that the **Okta Verify** app is installed on your **mobile device** and properly linked to your account before initiating the connection process. 
        > - Users leveraging SAML SSO through other identity providers cannot authenticate directly using their corporate credentials with the `Connect-HPEGL` cmdlet. 
        >   - As a workaround, invite a user with an email address that is not associated with any SAML SSO domains configured in the workspace. This can be done via the HPE GreenLake GUI under `User Management` by selecting `Invite Users`. Assign the HPE GreenLake Account Administrator role to the invited user. Once the invitation is accepted, the user can set a password and use these credentials to log in with `Connect-HPEGL`.
        
    
> **Note**: Managed Service Provider (MSP) workspaces are currently not supported.

## Installation 

To install the HPE Compute Ops Management PowerShell library, download the module and import it into your PowerShell session:

```sh
Install-Module HPECOMCmdlets
```

This will download and install the module from the official PowerShell Gallery repository. If this is your first time installing a module from the PowerShell Gallery, it will ask you to confirm whether you trust the repository or not. You can type `Y` and press **Enter** to continue with the installation.

>**Note**: You must have an internet connection to install the module from the PowerShell Gallery. 

>**Note**: This library has no dependencies, so it does not require the installation of any other software or modules to function properly.

>**Note**: You may encounter several issues while using the `Install-Module` cmdlet in PowerShell, including:
>    * **Insufficient Permissions**: You might need administrative privileges to install modules. If you lack these privileges, run your PowerShell client as an administrator or use: `Install-Module HPECOMCmdlets -Scope CurrentUser`.
>    * **Blocked Security Protocols**: PowerShell's security settings can sometimes block the installation process, especially if the execution policy is set to `Restricted`. If `Get-ExecutionPolicy` returns `Restricted`, run `Set-ExecutionPolicy RemoteSigned` to change it.

If you have previously installed the module and wish to update it to the latest version, you can use the following commands:

```sh
Get-Module -Name HPECOMCmdlets -ListAvailable | Uninstall-Module
Install-Module HPECOMCmdlets
```


## Getting Started

To get started, create a credentials object using your HPE GreenLake user's email and password and connect to your HPE GreenLake workspace:

```sh
$credentials = Get-Credential
Connect-HPEGL -Credential $credentials -Workspace "YourWorkspaceName"
```

If you don't have a workspace yet, use:

```sh
Connect-HPEGL -Credential $credentials 
```

 > **Note**: You do not need an existing HPE GreenLake workspace to connect. You can create a new workspace after your first connection using the `New-HPEGLWorkspace` cmdlet.

If you have multiple workspaces assigned to your account and are unsure which one to connect to, use:

```sh
Connect-HPEGL -Credential $credentials 
# Get the list of workspaces
Get-HPEGLWorkspace 
# Connect to the workspace you want using the workspace name
Connect-HPEGLWorkspace -Name "<WorkspaceName>"
```

These commands establishe and manage your connection to the HPE GreenLake platform. Upon successful connection, it creates a persistent session for all subsequent module cmdlet requests. Additionally, the cmdlet generates temporary API client credentials for both HPE GreenLake and any Compute Ops Management service instances provisioned in the workspace.

The global variable `$HPEGreenLakeSession` stores session information, API client credentials, API access tokens, and other relevant details for both HPE GreenLake and Compute Ops Management APIs.

To learn more about this object, refer to the help documentation of `Connect-HPEGL`.


## Script Samples


To help you get started quickly, I have provided a [sample script](https://github.com/jullienl/HPE-COM-PowerShell-Library/blob/main/Examples/sample.ps1). 

This file contains a variety of examples demonstrating how to use the different cmdlets available in the library to accomplish various tasks.

With HPE GreenLake:

- Setting up credentials and connecting to HPE GreenLake
- Configuring workspace, inviting new users and assigning roles
- Provisioning services and managing device subscriptions
- Adding devices individually or via CSV files

With HPE Compute Ops Management:

- Creating BIOS, internal storage, OS, and firmware settings.
- Managing group and adding servers to groups.
- Running inventory jobs and setting auto firmware updates.
- Powering on servers and updating firmware.
- Applying configurations and installing OS on servers.
- Generating sustainability reports and enabling email notifications.
- Adding external services like ServiceNow.
- Managing and upgrading HPE OneView and Secure Gateway appliances.

Feel free to modify and expand upon these examples to suit your specific needs. This file is an excellent starting point for understanding the capabilities of the module and how to leverage it in your automation workflows.


## Getting help

For more detailed information on each cmdlet and its usage, refer to the module's help documentation using:

```sh
Get-Help <CmdletName> -full
```

To see detailed examples of how to use a specific cmdlet, use the **Get-Help** cmdlet with the **\-Examples** parameter followed by the cmdlet name.

```sh
Get-Help <CmdletName> -Examples
```
To list all commands exported by the module, use:

```sh
Get-Command -Module HPECOMCmdlets
```

To find cmdlets related to a specific resource, use:

```sh
Get-Command -Module HPECOMCmdlets | ? Name -match "<ResourceName>" 
```

## Support

If you encounter any issues or unexpected behavior, please open a [new issue](https://github.com/jullienl/HPE-COM-PowerShell-Library/issues) on my GitHub issue tracker for assistance.

For general questions or discussions that don't require tracking, join our [GitHub Discussions](https://github.com/jullienl/HPE-COM-PowerShell-Library/discussions).


## Disclaimer

Please note that the HPE GreenLake APIs are subject to change. Such changes can impact the functionality of this library. We recommend keeping the library updated to the latest version to ensure compatibility with the latest API changes.


## Want more?

* [HPE GreenLake Edge-to-Cloud Platform User Guide](https://support.hpe.com/hpesc/public/docDisplay?docId=a001.0.122en_us)
* [HPE Compute Ops Management User Guide](https://www.hpe.com/info/com-ug)
* [HPE GreenLake Developer Portal](https://developer.greenlake.hpe.com/)


<!-- markdown variables links -->

[GL-master-psgallery-badge]: https://img.shields.io/powershellgallery/dt/HPECOMCmdlets?label=PSGallery
[GL-master-psgallery-link]: https://www.powershellgallery.com/packages/HPECOMCmdlets


<!-- MISC DO NOT TOUCH -->
[new-issue-badge-url]: https://img.shields.io/badge/issues-new-yellowgreen?style=flat&logo=github
[new-issue-link]: https://github.com/jullienl/HPE-COM-PowerShell-library/issues
[github-chat-badge-url]: https://img.shields.io/badge/chat-on%20github%20discussions-green?style=flat&logo=gitter
[github-chat-link]: https://github.com/jullienl/HPE-COM-PowerShell-library/discussions


## License
This library is provided under the MIT License. See the full license text in the module manifest for more details.

## Author
Lionel Jullien, Hewlett Packard Enterprise
