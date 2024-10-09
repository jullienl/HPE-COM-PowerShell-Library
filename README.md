## HPE GreenLake edge-to-cloud platform PowerShell library

The HPE GreenLake platform is a cutting-edge software-as-a-service platform that allows for seamless connectivity from the edge to the cloud. With this platform, you can expect a uniformly efficient and effective cloud experience for all your applications and data whether they are located on-premises or off-premises. The HPE GreenLake platform also provides valuable insights and controls that make it easy for you to manage your hybrid IT estate, complementing your existing use of public clouds and data centers.

This library allows PowerShell developers, IT automation engineers, or devops personnel to use the HPE GreenLake platform API to automate infrastructure policies and operations across multiple cloud resources. 

Among many other operations, this library allows you to create users, assign roles, send invitations to users, add and archive devices, assign applications and attach subscriptions, add tags to any device, and get all kinds of information about any HPE GreenLake resource. 

In addition, you can implement resource restriction policies, fully automate device onboarding, generate API credentials for specific application instances (such as HPE Compute Ops Management or HPE Data Services Cloud Console), and extend your API calls to any HPE GreenLake application instance on the fly.

Sample scripts are included in the library to demonstrate how it can be best used. These examples illustrate the variety of functionality in the library, including connecting to the platform, onboarding devices, generating API credentials, interacting with application instance APIs, etc.

## Latest release


1.1.6 |
------------ |
[![PS Gallery][GL-master-psgallery-badge]][GL-master-psgallery-link] |


## Supported PowerShell Editions

* PowerShell Desktop Edition (with 5.1 and above)  
* PowerShell Core Edition (with 7.x is supported on Windows, Linux and Mac)


## Getting started

Before using this library, it is necessary to have an HPE account linked to an HPE GreenLake workspace.

> **Note**: To learn how to set up an HPE account, see [Getting started with HPE GreenLake](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&page=GUID-497192AA-FDC2-49C5-B572-0D2F58A23745.html).

> **Note**: To interact with the HPE GreenLake platform through this library, you must possess at least the ***Observer*** built-in role in the ***HPE GreenLake platform*** application. This role only grants view privileges. However, if you need to make modifications, then either the ***Operator*** (with view and edit privileges) or the ***Administrator*** (with view, edit, and delete privileges) built-in roles are necessary. If none of these built-in roles are suitable, you can also create your own custom role that meets your role-based access control requirements.

## Installation of the library

To install the HPE GreenLake library to your local system, you can use the [`Install-Module`](https://go.microsoft.com/fwlink/?LinkID=398573) Cmdlet to install the module from the PowerShell Gallery:

```powerShell
Install-Module HPEGreenLake
```

This will download and install the module from the official PowerShell Gallery repository. If this is your first time installing a module from the PowerShell Gallery, it will ask you to confirm whether you trust the repository or not. You can type **Y** and press **Enter** to continue with the installation.

>**Note**: You must have an internet connection to install the module from the PowerShell Gallery. 

>**Note**: This library has no dependencies, so it does not require the installation of any other software or modules to function properly.

There could be several issues you may encounter while using the **Install-Module** cmdlet in PowerShell, some of which are:

* **Insufficient permissions**: You may need administrative privileges to install modules. If you do not have sufficient privileges, you can run your PowerShell client as an administrator or use: **Install-Module HPEGreenLake -Scope CurrentUser**
    
* **Blocked security protocols**: Sometimes, the security protocols built into PowerShell can prevent the installation process. This usually happens when the PowerShell execution policy is set to "Restricted". If Get-ExecutionPolicy shows Restricted, you may need to run **Set-ExecutionPolicy RemoteSigned**

If you have previously installed the module and wish to update it to the newest version, you can use:

```powerShell
Get-Module -Name HPEGreenLake -ListAvailable | Uninstall-Module  
Install-Module HPEGreenLake
```

## Connection to HPE GreenLake platform

For the connection, it is recommended that you create a credentials object that includes your HPE GreenLake user's email and password:

```powerShell
$GL_Username = "username@domain.com"
$GL_EncryptedPassword = "01000000d08c9ddf0115d1118c7a00c04fc297eb0100000007b4614ade6ce1489bd0283c5af38b7f0000000002000000000003660000c000000010000000031bd39e0cba34b7788afeb87796ac9e0000000004800000a000000010000000b32d72a7d8d9477e92303b3f91.1.655200000007c21c096c3b3518a7c62573ac7d220517c10bf5b73ac13bb9a1b819e3523a70014000000be59fe899e0b83f81cd9fbf0705c72c31.1.6cc1"
$GL_SecuredPassword = ConvertTo-SecureString $GL_EncryptedPassword
$GL_Credentials = New-Object System.Management.Automation.PSCredential ($GL_Username, $GL_SecuredPassword)
```

The encrypted password of the HPE GreenLake user is utilized in this example to enhance security. The variable **$GL_EncryptedPassword** can solely be decrypted from the machine where the encryption commands were executed. To encrypt your password on your local machine, you may use:

```powerShell
$Your_HPE_GreenLake_Password = "xxxxxxxxxxxxxx"
$GL_EncryptedPassword = ConvertTo-SecureString -String $Your_HPE_GreenLake_Password -AsPlainText -Force | ConvertFrom-SecureString  
```

Then using the **Connect-HPEGL** cmdlet, you can connect to the platform as follows:

```powerShell
Connect-HPEGL -Credential $GL_Credentials
```

If you have multiple workspaces, you can add the **\-Workspace** parameter to connect to the appropriate workspace as follows:

```powerShell
Connect-HPEGL -Credential $credentials -Workspace "HPE Mougins"
```

After successfully authenticating to the HPE GreenLake platform, the [HPEGreenLake.Connection] object is returned to the caller and (at the same time) is added to the global session tracker **$HPEGreenLakeSession**. To learn more about this object, see [about_HPEGreenLake_Connection.help](https://github.com/HewlettPackard/POSH-HPEGreenLake/blob/master/en-US/about_HPEGreenLake_Connection.help.txt)

## Known limitations


>**Note**: The library currently only supports single-factor authentication. Multi-factor authentication (MFA) and SAML Single Sign-On are not supported. 

>**Note**: This limitation means that users who use SAML single sign-on with the HPE GreenLake platform (this applies to all HPE employees) cannot use their corporate email credentials when logging in via the `Connect-HPEGL` cmdlet. 

> **Note**: While waiting for SAML Single Sign-On support, the temporary solution is to add a secondary email into your HPE GreenLake workspace. Just go to the HPE GreenLake GUI and use the **Invite Users** card in **Manage** / **Identity & Access** to send an invitation to a non-corporate email address. Once you receive the email, accept the invitation and you will be directed to the HPE GreenLake interface where you can set a password. Once this is done, you can use this email address and password to log in with `Connect-HPEGL`.



## Getting help

If you need help with Cmdlets in the library, you can access the documentation by using the command: 
```PowerShell
Get-Help <CmdletName> -full
```

To view the detailed examples of how to use a particular cmdlet, you can use the **Get-Help** cmdlet along with the **\-Examples** parameter followed by the name of the cmdlet.

```PowerShell
Get-Help <CmdletName> -ex
```

To get the list of commands exported by the module, you can use:

```PowerShell
> Get-Command -Module HPEGreenLake
```

To find all the cmdlets of the module that can be used with a specific resource, you can enter :

```PowerShell
> Get-Command -Module HPEGreenLake | ? name -match <ResourceName>
```

Additionally, if you encounter any issues or unexpected behavior, you can open a [![New issue][new-issue-badge-url]][new-issue-link] on the tracker to receive assistance.

You have a general question about the library?  For general questions, or need to discuss a topic that doesn't need to be tracked in the issue tracker, please join the  GitHub Discussions for the project: [![Join the discussion][github-chat-badge-url]][github-chat-link]

## Want more?

* [New PowerShell library for the HPE GreenLake platform | HPE Developer Portal](https://developer.hpe.com/blog/new-powershell-library-for-the-hpe-greenlake-cloud-platform/)
* [HPE GreenLake Developer Portal](https://developer.greenlake.hpe.com/)
* To learn more about the HPE GreenLake platform, see the [HPE GreenLake edge-to-cloud platform User Guide](https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us)

<!-- markdown variables links -->

[GL-master-psgallery-badge]: https://img.shields.io/powershellgallery/dt/HPEGreenLake?label=PSGallery
[GL-master-psgallery-link]: https://www.powershellgallery.com/packages/HPEGreenLake


<!-- MISC DO NOT TOUCH -->
[new-issue-badge-url]: https://img.shields.io/badge/issues-new-yellowgreen?style=flat&logo=github
[new-issue-link]: https://github.com/HewlettPackard/POSH-HPEGreenLake/issues
[github-chat-badge-url]: https://img.shields.io/badge/chat-on%20github%20discussions-green?style=flat&logo=gitter
[github-chat-link]: https://github.com/HewlettPackard/POSH-HPEGreenLake/discussions/

