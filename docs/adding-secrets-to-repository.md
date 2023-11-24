## Adding secrets to the GitHub repository

Secrets are variables that I've created in the repository. The secrets are available to use in the GitHub Actions workflow. GitHub Actions can only read a secret if it's explicitly included in a workflow.

As it is advisable to never hard code variables as this can lead to security vulnerabilities and reduces the reusability of the workflow file. I treat all variables as secrets, even if the variable value isn't sensitive.

### Bash script

To ease setup of the GitHub repository secrets, I have created a bash script [add-workflow-secrets.sh](../bin/add-workflow-secrets.sh).

I obtain the variable values dynamically from an Azure resource group defined as a local development environment variable named RESOURCE_GROUP. The script uses Azure Cli to run commands to retrieve the required values, then the script builds a .env file locally. GitHub Cli then uses this .env file to create the repository secrets. The .env file is then deleted.

You must first configure your developer environment and GitHub to use GitHub CLI. See instructions detailed in document [GitHub CLI Setup](github-cli-setup.md).

### Running the script

```bash
./bin/add-workflow-secrets.sh
```

### Review of the [add-workflow-secrets.sh](../bin/add-workflow-secrets.sh) bash script

The first lines of the script are for formatting the error messages.

```bash
## ...

# Text formatting
declare red=`tput setaf 1`
declare bold=`tput bold`
declare newline=$'\n'

# Element styling
declare errorStyle="${red}${bold}"

## ...
```

Then I check that the environmental variable RESOURCE_GROUP has been set in the development environment. If the variable is empty the script displays an error message, then the script exits.

```bash
## ...

# Check resourceGroup variable has a value
if [ -z "$resourceGroup" ]
then
  echo "${newline}${errorStyle}ERROR: RESOURCE_GROUP not defined as environment variable.${defaultTextStyle}${newline}"
  exit 1
fi

## ...
```

I then use the [gh repo view](https://cli.github.com/manual/gh_repo_view) GitHub CLI command to assign a value to local variable 'appName'.

```bash
## ...

appName=$(gh repo view --json name -q ".name")

## ...
```

By using the Azure CLI command [az ad app list](https://learn.microsoft.com/en-us/cli/azure/ad/app?view=azure-cli-latest#az-ad-app-list), I create a local variable 'clientId' then check the variable is not empty. If the variable is empty the script displays an error message, then the script exits. This variable value will be used for repository secret AZURE_CLIENT_ID.

```bash
## ...

clientId=$(az ad app list --display-name ${appName} --query "[].appId" --output tsv)

# Microsoft Entra application check
if [ -z "$clientId" ]
then
  echo "${newline}${errorStyle}ERROR: Client Id not defined, have you run azure-oidc-setup.sh?.${defaultTextStyle}${newline}"
  exit 1
fi

## ...
```

The second repository secret is AZURE_TENANT_ID. I retrieve the value for this using Azure Cli command [az account show](https://learn.microsoft.com/en-us/cli/azure/account?view=azure-cli-latest#az-account-show). If the variable is empty the script displays an error message, then the script exits.


```bash
## ...

azureTenantId=$(az account show --query "tenantId" --output tsv)

if [ -z "$azureTenantId" ]
then
  echo "${newline}${errorStyle}ERROR: Tenant ID not found!${defaultTextStyle}${newline}"
  exit 1
fi

## ...
```

The third repository secret is AZURE_SUBSCRIPTION_ID. I retrieve the value for this using Azure Cli command [az account show](https://learn.microsoft.com/en-us/cli/azure/account?view=azure-cli-latest#az-account-show). If the variable is empty the script displays an error message, then the script exits.

```bash
## ...

azureSubscriptionId=$(az account show --query "id" --output tsv)

if [ -z "$azureSubscriptionId" ]
then
  echo "${newline}${errorStyle}ERROR: Subscription ID not found!${defaultTextStyle}${newline}"
  exit 1
fi

## ...
```

The fourth repository secret is STORAGE_ACCOUNT_NAME. I retrieve the value for this using Azure Cli command [az storage account list](https://learn.microsoft.com/en-us/cli/azure/storage/account?view=azure-cli-latest#az-storage-account-list). If the variable is empty the script displays an error message, then the script exits.

```bash
## ...

storageAccountName=$(az storage account list --resource-group ${resourceGroup} --query "[].name" --output tsv)

if [ -z "$storageAccountName" ]
then
  echo "${newline}${errorStyle}ERROR: Storage account not found!${defaultTextStyle}${newline}"
  exit 1
fi

## ...
```

The fifth repository secret is CDN_PROFILE_NAME. I retrieve the value for this using Azure Cli command [az afd profile list](https://learn.microsoft.com/en-us/cli/azure/afd/profile?view=azure-cli-latest#az-afd-profile-list). If the variable is empty the script displays an error message, then the script exits.

```bash
## ...

cdnProfileName=$(az afd profile list --resource-group ${resourceGroup} --query "[].name" --output tsv)

if [ -z "$cdnProfileName" ]
then
  echo "${newline}${errorStyle}ERROR:  Azure Front Door profile not found!${defaultTextStyle}${newline}"
  exit 1
fi

## ...
```

The sixth repository secret is CDN_ENDPOINT. I retrieve the value for this using Azure Cli command [az afd endpoint list](https://learn.microsoft.com/en-us/cli/azure/afd/endpoint?view=azure-cli-latest#az-afd-endpoint-list). If the variable is empty the script displays an error message, then the script exits.

```bash
## ...

cdnEndpoint=$(az afd endpoint list --resource-group ${resourceGroup} --profile-name ${cdnProfileName} --query "[].name" --output tsv)

if [ -z "$cdnEndpoint" ]
then
  echo "${newline}${errorStyle}ERROR: Azure Front Door endpoint not found!${defaultTextStyle}${newline}"
  exit 1
fi

## ...
```

I now have the values for all the repository secrets. I create a local .env file. I use heredoc string literals for readability.

```bash
## ...

# Use Heredoc to create a .env file
cat > ".env" << EOF
AZURE_CLIENT_ID=${clientId}
AZURE_TENANT_ID=${azureTenantId}
AZURE_SUBSCRIPTION_ID=${azureSubscriptionId}
STORAGE_ACCOUNT_NAME=${storageAccountName}
CDN_PROFILE_NAME=${cdnProfileName}
CDN_ENDPOINT=${cdnEndpoint}
RESOURCE_GROUP=${resourceGroup}
EOF

## ...
```

Using the GitHub Cli command [gh secret set](https://cli.github.com/manual/gh_secret_set) with the -f parameter, I can load secret names and values from the .env file.

```bash
## ...

gh secret set -f .env

## ...
```

Finally I clean up, and remove the .env file from the local development machine.

```bash
## ...

rm .env 2>/dev/null

## ...
```

After the script complete the GitHub repository now has all the secrets required to be passed to the GitHub Action workflow.