# HPE GreenLake for Compute Ops Management PowerShell library 

The HPE GreenLake for Compute Ops Management PowerShell library provides a set of cmdlets to manage and automate your HPE GreenLake environment. This library allows users to interact with HPE GreenLake and Compute Ops Management services directly from the PowerShell command line, enabling seamless integration into your existing automation workflows.


## Key Features

- **Authentication**: Connect to HPE GreenLake using single-factor authentication.
- **Workspace Management**: Create and manage HPE GreenLake workspaces.
- **Session Tracking**: Automatically track sessions with the global session tracker `$HPEGreenLakeSession`.
- **User Management**: Invite and manage users within your HPE GreenLake environment.
- **Resource Management**: Manage resources such as servers, storage, and networking within your HPE GreenLake environment.
- **Monitoring and Alerts**: Set up monitoring and alerts for your resources to ensure optimal performance and uptime.
- **Reporting**: Generate detailed reports on resource usage, performance, and other metrics.
- **Automation**: Automate repetitive tasks and workflows using PowerShell scripts and cmdlets.
- **Integration**: Seamlessly integrate with other tools and platforms using REST APIs and webhooks.
- **Security**: Implement security best practices and manage access control for your HPE GreenLake environment.

The HPE GreenLake for Compute Ops Management PowerShell library includes a comprehensive set of cmdlets to manage various aspects of your HPE GreenLake environment and any existing Compute Ops Management service instances. For a complete list of cmdlets and their detailed usage, refer to the module's help documentation using the `Get-Help` cmdlet.


## Latest release

1.0.0 |
------------ |
[![PS Gallery][GL-master-psgallery-badge]][GL-master-psgallery-link] |


## Requirements 

- **PowerShell Version**: 5.1 or higher
- **Supported PSEditions**: Desktop, Core
- **HPE Account**: If you do not have an HPE Account, you can create one at https://common.cloud.hpe.com.
     

    > **Note**: To learn how to create an HPE account, see [Getting started with HPE GreenLake](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&page=GUID-497192AA-FDC2-49C5-B572-0D2F58A23745.html)

    > **Note**: To interact with an HPE GreenLake workspace and a Compute Ops Management instance using this library, you must have at least the ***Observer*** role for both ***HPE GreenLake Platform*** and ***Compute Ops Management*** service managers. This role grants view-only privileges. For modification capabilities, you need either the ***Operator*** (view and edit privileges) or the ***Administrator*** (view, edit, and delete privileges) role. Alternatively, you can create a custom role that meets your specific access requirements.

    > **Note**: The library supports only single-factor authentication. Multi-factor authentication (MFA) and SAML Single Sign-On are not supported. Users who use SAML Single Sign-On with HPE GreenLake cannot use their corporate email credentials when logging in via the `Connect-HPEGL` cmdlet. The workaround is to create a specific user in HPE GreenLake for this library. To do this, go to the HPE GreenLake GUI, click on `User Management` in the quick links panel and press the `Invite Users` button to send an invitation to a non-corporate email address. Once you receive the email, accept the invitation, and you will be directed to the HPE GreenLake interface to set a password. You can then use this email address and password to log in with `Connect-HPEGL`.

    > **Note**: You do not need an existing HPE GreenLake workspace to connect. You can create a new workspace after your first connection using the `New-HPEGLWorkspace` cmdlet.


## Installation 

To install the HPE GreenLake for Compute Ops Management PowerShell library, download the module and import it into your PowerShell session:

```powerShell
Install-Module HPEGreenLakeForCOM
```

This will download and install the module from the official PowerShell Gallery repository. If this is your first time installing a module from the PowerShell Gallery, it will ask you to confirm whether you trust the repository or not. You can type `Y` and press **Enter** to continue with the installation.

>**Note**: You must have an internet connection to install the module from the PowerShell Gallery. 

>**Note**: This library has no dependencies, so it does not require the installation of any other software or modules to function properly.

>**Note**: There could be several issues you may encounter while using the `Install-Module` cmdlet in PowerShell, some of which are:
>    * **Insufficient permissions**: You may need administrative privileges to install modules. If you do not have sufficient privileges, you can run your PowerShell client as an administrator or use: `Install-Module HPEGreenLakeForCOM -Scope CurrentUser`
>    * **Blocked security protocols**: Sometimes, the security protocols built into PowerShell can prevent the installation process. This usually happens when the PowerShell execution policy is set to `Restricted`. If `Get-ExecutionPolicy` shows `Restricted`, you may need to run `Set-ExecutionPolicy RemoteSigned`

If you have previously installed the module and wish to update it to the latest version, you can use the following commands:

```PowerShell
Get-Module -Name HPEGreenLakeForCOM -ListAvailable | Uninstall-Module
Install-Module HPEGreenLakeForCOM
```


## Getting Started

To get started, create a credentials object using your HPE GreenLake user's email and password and connect to your HPE GreenLake workspace:


```powerShell
$credentials = Get-Credential
Connect-HPEGL -Credential $credentials -Workspace "YourWorkspaceName"
```

If you don't have a workspace yet, use:

```powerShell
Connect-HPEGL -Credential $credentials 
```

This cmdlet establishes and manages your connection to the HPE GreenLake platform. Upon successful connection, it creates a persistent session for all subsequent module cmdlet requests. Additionally, the cmdlet generates temporary API client credentials for both HPE GreenLake and any Compute Ops Management service instances provisioned in the workspace.

The global variable `$HPEGreenLakeSession` stores session information, API client credentials, API access tokens, and other relevant details for both HPE GreenLake and Compute Ops Management APIs.

To learn more about this object, refer to the help documentation of `Connect-HPEGL`.


## Getting help

For more detailed information on each cmdlet and its usage, refer to the module's help documentation using:

```PowerShell
Get-Help <CmdletName> -full
```

To see detailed examples of how to use a specific cmdlet, use the **Get-Help** cmdlet with the **\-Examples** parameter followed by the cmdlet name.

```PowerShell
Get-Help <CmdletName> -Examples
```
To list all commands exported by the module, use:

```PowerShell
Get-Command -Module HPEGreenLakeForCOM
```

To find cmdlets related to a specific resource, use:

```PowerShell
Get-Command -Module HPEGreenLakeForCOM | Where-Object { $_.Name -match "<ResourceName>" }
```


## Support

If you encounter any issues or unexpected behavior, please open a [new issue][new-issue-link] on our issue tracker for assistance.

For general questions or discussions that don't require tracking, join our GitHub Discussions: [Join the discussion][github-chat-link]


## Disclaimer

Please note that the HPE GreenLake APIs are subject to change. Such changes can impact the functionality of this library. We recommend keeping the library updated to the latest version to ensure compatibility with the latest API changes.


## Want more?

* [HPE GreenLake Developer Portal](https://developer.greenlake.hpe.com/)
* To learn more about HPE GreenLake, see the [HPE GreenLake Edge-to-Cloud Platform User Guide](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us)

<!-- markdown variables links -->

[GL-master-psgallery-badge]: https://img.shields.io/powershellgallery/dt/HPEGreenLake?label=PSGallery
[GL-master-psgallery-link]: https://www.powershellgallery.com/packages/HPEGreenLakeForCOM


<!-- MISC DO NOT TOUCH -->
[new-issue-badge-url]: https://img.shields.io/badge/issues-new-yellowgreen?style=flat&logo=github
[new-issue-link]: https://github.com/jullienl/HPE-COM-PowerShell-library/issues
[github-chat-badge-url]: https://img.shields.io/badge/chat-on%20github%20discussions-green?style=flat&logo=gitter
[github-chat-link]: https://github.com/jullienl/HPE-COM-PowerShell-library/discussions


## License
This library is provided under the MIT License. See the full license text in the module manifest for more details.

## Author
Lionel Jullien, Hewlett-Packard Enterprise