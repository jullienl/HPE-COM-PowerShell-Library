# HPE GreenLake for Compute Ops Management PowerShell library 

The HPE GreenLake for Compute Ops Management PowerShell library provides a set of cmdlets to manage and automate your HPE GreenLake environment. Developed by Hewlett-Packard Enterprise, this library allows users to interact with HPE GreenLake and Compute Ops Management services directly from the PowerShell command line, enabling seamless integration into your existing automation workflows.


## Key Features

- **Authentication**: Connect to HPE GreenLake using single-factor authentication.
- **Workspace Management**: Create and manage HPE GreenLake workspaces.
- **Session Tracking**: Automatically track sessions with the global session tracker `$HPEGreenLakeSession`.
- **User Management**: Invite and manage users within your HPE GreenLake environment.



## Latest release

1.0.0 |
------------ |
[![PS Gallery][GL-master-psgallery-badge]][GL-master-psgallery-link] |


## Requirements 

- **PowerShell Version**: 5.1 or higher
- **Supported PSEditions**: Desktop, Core
- **HPE Account**: See [Getting started with HPE GreenLake](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&page=GUID-497192AA-FDC2-49C5-B572-0D2F58A23745.html)

    > **Note**: To interact with the HPE GreenLake platform using this library, you must have at least the ***Observer*** role in the ***HPE GreenLake platform*** application. This role grants view-only privileges. For modification capabilities, you need either the ***Operator*** (view and edit privileges) or the ***Administrator*** (view, edit, and delete privileges) role. Alternatively, you can create a custom role that meets your specific access requirements.

    > **Note**: You do not need an existing HPE GreenLake workspace to connect. You can create a new workspace after your first connection using the `New-HPEGLWorkspace` cmdlet.

    > **Note**: The library supports only single-factor authentication. Multi-factor authentication (MFA) and SAML Single Sign-On are not supported.

    > **Note**: Users who use SAML Single Sign-On with HPE GreenLake cannot use their corporate email credentials when logging in via the `Connect-HPEGL` cmdlet. The workaround is to create a specific user in HPE GreenLake for this library. To do this, go to the HPE GreenLake GUI and use the **Invite Users** card in **Manage** / **Identity & Access** to send an invitation to a non-corporate email address. Once you receive the email, accept the invitation, and you will be directed to the HPE GreenLake interface to set a password. You can then use this email address and password to log in with `Connect-HPEGL`.



## Installation 

To install the HPE GreenLake for Compute Ops Management PowerShell library, download the module and import it into your PowerShell session:

```powerShell
Install-Module HPEGreenLakeForCOM
```

This will download and install the module from the official PowerShell Gallery repository. If this is your first time installing a module from the PowerShell Gallery, it will ask you to confirm whether you trust the repository or not. You can type **Y** and press **Enter** to continue with the installation.

>**Note**: You must have an internet connection to install the module from the PowerShell Gallery. 

>**Note**: This library has no dependencies, so it does not require the installation of any other software or modules to function properly.

There could be several issues you may encounter while using the **Install-Module** cmdlet in PowerShell, some of which are:

* **Insufficient permissions**: You may need administrative privileges to install modules. If you do not have sufficient privileges, you can run your PowerShell client as an administrator or use: **Install-Module HPEGreenLakeForCOM -Scope CurrentUser**
    
* **Blocked security protocols**: Sometimes, the security protocols built into PowerShell can prevent the installation process. This usually happens when the PowerShell execution policy is set to "Restricted". If Get-ExecutionPolicy shows Restricted, you may need to run **Set-ExecutionPolicy RemoteSigned**

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

After successfully authenticating to HPE GreenLake, the `[HPEGreenLake.Connection]` object is returned to the caller and added to the global session tracker `$HPEGreenLakeSession`. 
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

If you encounter any issues or unexpected behavior, you can open a [new issue][new-issue-link] on the tracker for assistance.

For general questions or discussions that don't need to be tracked in the issue tracker, join the GitHub Discussions for the project: [Join the discussion][github-chat-link]

## Want more?

* [New HPE GreenLake for Compute Ops Management PowerShell library ](https://developer.hpe.com/blog/new-powershell-library-for-the-hpe-greenlake-cloud-platform/)
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