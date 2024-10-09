## HPE GreenLake for Compute Ops Management PowerShell library 

The HPE GreenLake platform is a cutting-edge software-as-a-service platform that allows for seamless connectivity from the edge to the cloud. With this platform, you can expect a uniformly efficient and effective cloud experience for all your applications and data whether they are located on-premises or off-premises. The HPE GreenLake platform also provides valuable insights and controls that make it easy for you to manage your hybrid IT estate, complementing your existing use of public clouds and data centers.

This library allows PowerShell developers, IT automation engineers, or devops personnel to use the HPE GreenLake platform API to automate infrastructure policies and operations across multiple cloud resources. 

Among many other operations, this library allows you to create users, assign roles, send invitations to users, add and archive devices, assign applications and attach subscriptions, add tags to any device, and get all kinds of information about any HPE GreenLake resource. 

In addition, you can implement resource restriction policies, fully automate device onboarding, generate API credentials for specific application instances (such as HPE Compute Ops Management or HPE Data Services Cloud Console), and extend your API calls to any HPE GreenLake application instance on the fly.

Sample scripts are included in the library to demonstrate how it can be best used. These examples illustrate the variety of functionality in the library, including connecting to the platform, onboarding devices, generating API credentials, interacting with application instance APIs, etc.

## Latest release


1.0.0 |
------------ |
[![PS Gallery][GL-master-psgallery-badge]][GL-master-psgallery-link] |


## Supported PowerShell Editions

* PowerShell Desktop Edition (with 5.1 and above)  
* PowerShell Core Edition (with 7.x is supported on Windows, Linux and Mac)


## Getting started

Before using this library, you must have an HPE account. 

> **Note**: To learn how to create an HPE account, see [Getting started with HPE GreenLake](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&page=GUID-497192AA-FDC2-49C5-B572-0D2F58A23745.html).

> **Note**: To interact with the HPE GreenLake platform through this library, you must possess at least the ***Observer*** built-in role in the ***HPE GreenLake platform*** application. This role only grants view privileges. However, if you need to make modifications, then either the ***Operator*** (with view and edit privileges) or the ***Administrator*** (with view, edit, and delete privileges) built-in roles are necessary. If none of these built-in roles are suitable, you can also create your own custom role that meets your role-based access control requirements.

> **Note**: An HPE GreenLake workspace is not a prerequisite, as it can be created after the first connection using `New-HPEGLWorkspace`.

## Installation of the library

To install this library to your local system, you can use the [`Install-Module`](https://go.microsoft.com/fwlink/?LinkID=398573) Cmdlet to install the module from the PowerShell Gallery:

```powerShell
Install-Module HPEGreenLakeForCOM
```

This will download and install the module from the official PowerShell Gallery repository. If this is your first time installing a module from the PowerShell Gallery, it will ask you to confirm whether you trust the repository or not. You can type **Y** and press **Enter** to continue with the installation.

>**Note**: You must have an internet connection to install the module from the PowerShell Gallery. 

>**Note**: This library has no dependencies, so it does not require the installation of any other software or modules to function properly.

There could be several issues you may encounter while using the **Install-Module** cmdlet in PowerShell, some of which are:

* **Insufficient permissions**: You may need administrative privileges to install modules. If you do not have sufficient privileges, you can run your PowerShell client as an administrator or use: **Install-Module HPEGreenLakeForCOM -Scope CurrentUser**
    
* **Blocked security protocols**: Sometimes, the security protocols built into PowerShell can prevent the installation process. This usually happens when the PowerShell execution policy is set to "Restricted". If Get-ExecutionPolicy shows Restricted, you may need to run **Set-ExecutionPolicy RemoteSigned**

If you have previously installed the module and wish to update it to the newest version, you can use:

```powerShell
Get-Module -Name HPEGreenLakeForCOM -ListAvailable | Uninstall-Module  
Install-Module HPEGreenLakeForCOM
```

## Connection to HPE GreenLake platform

To connect the library to HPE GreenLake, create a credentials object that includes your HPE GreenLake user's email and password for use with `Connect-HPEGL`:

```powerShell
$credentials = Get-Credential
Connect-HPEGL -Credential $credentials 
```

If you already have a workspace or multiple workspaces, you can use the `-Workspace` parameter to connect to the appropriate workspace:

```powerShell
Connect-HPEGL -Credential $credentials -Workspace "HPE Mougins"
```
After successfully authenticating to HPE GreenLake, the [HPEGreenLake.Connection] object is returned to the caller and added to the global session tracker **$HPEGreenLakeSession**. To learn more about this object, see [about_HPEGreenLake_Connection.help](https://github.com/HewlettPackard/POSH-HPEGreenLake/blob/master/en-US/about_HPEGreenLake_Connection.help.txt)


>**Note**: The library supports only single-factor authentication. Multi-factor authentication (MFA) and SAML Single Sign-On are not supported.

>**Note**: Users who use SAML Single Sign-On with HPE GreenLake cannot use their corporate email credentials when logging in via the `Connect-HPEGL` cmdlet. The workaround is to create a specific user in HPE GreenLake for this library. To do this, go to the HPE GreenLake GUI and use the **Invite Users** card in **Manage** / **Identity & Access** to send an invitation to a non-corporate email address. Once you receive the email, accept the invitation, and you will be directed to the HPE GreenLake interface to set a password. You can then use this email address and password to log in with `Connect-HPEGL`.


## Getting help

For detailed documentation on any cmdlet in the library, use the following command:
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

