<meta name="google-site-verification" content="ekN4eYyUb3noZEqgRg8BWMBhAzrWSCuNkvYByWGRGKk" />

# HPE Compute Ops Management PowerShell Library 

The HPE Compute Ops Management PowerShell library (`HPECOMCmdlets`) offers a comprehensive suite of cmdlets designed to manage and automate your HPE GreenLake environment. By leveraging this library, users can seamlessly interact with HPE GreenLake and Compute Ops Management services directly from the PowerShell command line, enabling efficient integration into existing automation workflows and enhancing operational efficiency.

Development is ongoing, and the library will be continuously updated to support new features as they are released by HPE.


## Latest release

1.0.13 |
------------ |
[![PS Gallery][GL-master-psgallery-badge]][GL-master-psgallery-link] |



📘 For detailed insights, tutorials, and updates, visit my blog: [PowerShell Library for HPE Compute Ops Management](https://jullienl.github.io/PowerShell-library-for-HPE-GreenLake).



## Requirements

- **Supported PowerShell Version**: 7 or higher. 

    > **Note**: PowerShell version 5 is no longer supported. 

- **Supported PowerShell Editions**: PowerShell Core version 7 or higher.

- **HPE Account**: An HPE Account is necessary to connect to the HPE GreenLake platform and any Compute Ops Management services.
     
    > **Note**: If you do not have an HPE Account, you can create one [here](https://common.cloud.hpe.com). To learn how to create an HPE account, see [Getting started with HPE GreenLake](https://support.hpe.com/hpesc/public/docDisplay?docId=a001.0.132en_us&page=GUID-497192AA-FDC2-49C5-B572-0D2F58A23745.html)

    > **Note**: To interact with an HPE GreenLake workspace and a Compute Ops Management instance using this library, you must have at least the ***Observer*** role for both ***HPE GreenLake Platform*** and ***Compute Ops Management*** service managers. This role grants view-only privileges. For modification capabilities, you need either the ***Operator*** (view and edit privileges) or the ***Administrator*** (view, edit, and delete privileges) role. Alternatively, you can create a custom role that meets your specific access requirements.

- **Supported authentication methodes**:
    - **Single-factor** authentication.
    - **Multi-factor** authentication (MFA) using **Google Authenticator** or **Okta Verify**.       
    - **SAML Single Sign-On** (SSO) but exclusively with **Okta**. 
       

## How to Install the Module  

To install the library, use the following command to download and install the module from the official PowerShell Gallery:

```powershell
Install-Module HPECOMCmdlets
```

##  How to Upgrade the Module 

If you have already installed the module and need to update it to the latest version, run the following commands:

```powershell
# Install or update HPECOMCmdlets module
Install-Module -Name HPECOMCmdlets -Force -AllowClobber
```


## Support

If you encounter any issues or unexpected behavior, please open a [new issue](https://github.com/jullienl/HPE-COM-PowerShell-Library/issues) on my GitHub issue tracker for assistance.

For general questions or discussions that don't require tracking, join our [GitHub Discussions](https://github.com/jullienl/HPE-COM-PowerShell-Library/discussions).


## Disclaimer

Please note that the HPE GreenLake APIs are subject to change. Such changes can impact the functionality of this library. We recommend keeping the library updated to the latest version to ensure compatibility with the latest API changes.


## Want more?

🔗 [PowerShell Gallery](https://www.powershellgallery.com/packages/HPECOMCmdlets)

* [HPE GreenLake Edge-to-Cloud Platform User Guide](https://support.hpe.com/hpesc/public/docDisplay?docId=a001.0.132en_us)
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
