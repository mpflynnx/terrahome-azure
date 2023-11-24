# static-website-azure-oidc

This is my template project for automating the upload of static website source files to Azure Storage. 

Azure provides a low cost way to host a static website.

## Azure "12 Months Free"

New Azure users can signup and get this for free.

| Service | Monthly Limits |
| --- | --- |
| Blob Storage | 5gb storage 20k reads / 10k writes |

## Micro-Transaction Services

| Service | Pay per sip |
| --- | --- |
| Egress | $0.087 / GB |
| Azure Storage | $0.0184 / gb / month |
| Azure Storage | $0.05 / 10k writes |
| Azure Storage | $0.004 / 10k writes |

Static Website has a free tier with the following limits: 

- Bandwidth: 100gb
- Free SSL Certificates
- Storage: 0.50gb

Only available in these regions:
- westus2
- centralus
- eastus2
- westeurope
- eastasia

Special thanks for the above information from [Mark Tinderholt](https://github.com/markti/azure-serverless-demo).

## Project prerequisites

- An Azure account with an active subscription. [Create an account for free](https://azure.microsoft.com/free/?WT.mc_id=A261C142F).
- An Azure restricted user account for development (optional, but recommended).
- A provisioned static website hosted in Azure Storage with Azure Front Door CDN. See my [Terraform Azure static site]() repository.
- A GitHub account. If you do not have a GitHub account, [sign up for free](https://github.com/join).
- [GitHub CLI](https://cli.github.com/) installed and [authenticated](./docs/github-cli-setup.md)[<sup>[4]</sup>](#references) to a GitHub account.
- [Azure CLI](https://learn.microsoft.com/en-gb/cli/azure/what-is-azure-cli) installed and [authorised](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-device-code) with your Azure user login.
- Gitpod account (optional). For cloud based development environment[<sup>[5]</sup>](#references). [Try for free](https://gitpod.io/login/)

## GitHub Actions

Automation or continuos integration (CI) is achieved by using a GitHub Action [workflow](.github/workflows/upload.yml) file stored in the '.github/workflows' folder. A push to the [public](./public/) folder of the main branch will start the workflow. 

The workflow will:

- Upload the content of the public folder to the Azure storage.
- Purge the Front Door CDN, so that the old content is removed from the edge locations.

Refer to document: [Github Actions Workflow](/docs/github-action-workflow-explanation.md)[<sup>[1]</sup>](#references) for a more detailed explanation.

## Setting up a GitHub repository to use this template

### Step 1 - Create a repository from the template
In your browser, navigate to my [Static Website Azure OIDC](https://github.com/mpflynnx/static-website-azure-oidc) template repository.

Select Use this template, then select Create a new repository.

In the Owner dropdown, select your personal GitHub account.

Next, enter any suitable name for your static website as the Repository name.

Finally, select Public and click Create repository from template.


### Step 2 - Environment variables

Set environmental variables in the development environment.

1. Set GITHUB_TOKEN environmental variable, to avoid being prompted to authenticate GitHub CLI. For instructions refer to [GitHub CLI setup](./docs/github-cli-setup.md).[<sup>[4]</sup>](#references)

1. Set RESOURCE_GROUP environmental variable. This is the Azure resource group you have provisioned the storage account to.

### Step 3 - OpenID Connect with GitHub Actions workflow

For this repository, I have used [OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect) as a authentication method to Azure. 

OpenID Connect (OIDC) configures the GitHub Action workflow to request a short-lived access token directly from the Azure. A trust relationship is configured that controls which workflows are able to request the access tokens.

To ease setup, I have created a bash script [azure-oidc-setup.sh](./bin/azure-oidc-setup.sh) which will automate the process of setting up Azure OIDC with this repository and the GitHub Action workflow.

Refer to document: [Azure OIDC setup](/docs/azure-oidc-setup.md)[<sup>[2]</sup>](#references) for a more detailed explanation of the script.

### Step 4 - GitHub repository secrets

The workflow file needs to retrieve variables to successfully complete. It is advisable to never hard code variables as this can lead to security vulnerabilities and reduces the reusability of the workflow file.

I store these variables as secrets in the GitHub repository. I obtain most of the variable values from an Azure resource group and the GitHub repository. To ease setup of the GitHub repository secrets, I have created a bash script [add-workflow-secrets.sh](./bin/add-workflow-secrets.sh)

Refer to document: [Adding secrets to repository](/docs/adding-secrets-to-repository.md)[<sup>[3]</sup>](#references) for a more detailed explanation of the script.

## Static website source files

Source files for the static website are stored in the [public](./public/) folder of the repository.


## Recommended GitHub flow

- Create a new issue to work on your static site source files.
- Create a new feature branch to work on the issue.
when ready, commit your updates to the feature branch.
- Create a pull request to merge the feature branch into the main branch.
- The GitHub Action workflow will begin automatically and your static site updates will be uploaded and the CDN purged.
- The updated static website should be available across the globe.

## References

- [GitHub Action workflow file explanation](./docs/github-action-workflow-explanation.md) <sup>[1]</sup>
- [Azure OIDC setup](./docs/azure-oidc-setup.md) <sup>[2]</sup>
- [Adding secrets to the GitHub repository](./docs/adding-secrets-to-repository.md) <sup>[3]</sup>
- [Setting up GitHub Cli authentication](./docs/github-cli-setup.md) <sup>[4]</sup>
- [Gitpod development environment](./docs/gitpod-development-environment.md) <sup>[5]</sup>
- [Azure new user creation](./docs/new-azure-user-script-explanation.md) <sup>[6]</sup>