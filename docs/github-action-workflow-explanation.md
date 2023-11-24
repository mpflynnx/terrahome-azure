## GitHub Action workflow file explanation

Before the workflow file will function successfully you must first add secrets to the GitHub repository. See instructions detailed in document [Adding secrets to the GitHub repository](adding-secrets-to-repository.md).

By using this workflow to deploy a static site to an Azure storage account. I will be able to automatically deploy the site to Azure from GitHub when changes are pushed to the repositories main branch.

The [workflow](../.github/workflows/upload.yml) will:

- Upload the content of the repositories [public](./public/) folder to the Azure storage blob.
- Purge the Front Door CDN, so that the old content is removed from the edge locations.

### Review GitHub Action workflow file

The first line defines the name of the Actions workflow.

```yml
name: Blob storage website CI
## ...
```
Next, the configuration states that this workflow should only run when a push event occurs to the main branch and the changes include files in the public folder or subfolders. It also defines environment variables used by the workflow. The values are retrieved from the repositories secrets. Refer to document: [Adding secrets to repository](/docs/adding-secrets-to-repository.md) for a more detailed explanation of how I do this.

```yml
## ...

on:
  push:
    branches:
      - main
    paths:
      - 'public/**'

env:
  source-path: "./public/"
  storage-account-name: ${{ secrets.STORAGE_ACCOUNT_NAME }}
  cdn-profile-name: ${{ secrets.CDN_PROFILE_NAME }}
  cdn-endpoint: ${{ secrets.CDN_ENDPOINT }}
  resource-group: ${{ secrets.RESOURCE_GROUP }}

## ...
```

Then, we specify the permissions required to run the workflow step named 'Login' using OIDC.

```yml
## ...

permissions:
      id-token: write
      contents: read

## ..
```

Then, the configuration defines a build job, that runs on the Ubuntu latest GitHub-hosted runner. Each [GitHub-hosted runner](https://docs.github.com/en/actions/using-github-hosted-runners/about-github-hosted-runners/about-github-hosted-runners#overview-of-github-hosted-runners) is a new virtual machine (VM) hosted by GitHub with the runner application and other tools preinstalled.

```yml
## ...
jobs:
  build:
    runs-on: ubuntu-latest
## ...
```

The workflow define several steps.

- Checkout checks out the repository. Uses defines the GitHub action to run that specific step. The checkout step uses GitHub's [actions/checkout@v3](https://github.com/actions/checkout/tree/v3/) action.

```yml
## ...
steps:
    - name: Checkout
      uses: actions/checkout@v3
## ...
```

- Login to Azure, this uses GitHub action [azure/login](https://github.com/azure/login/tree/v1/). Pass the client-id, tenant-id and subscription-id of the Azure service principal associated with an OIDC Federated Identity Credential.

```yml
## ...
    - name: Login to Azure
      uses: azure/login@v1
      with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
## ...
```

- Upload to blob storage, this uses GitHub action [azure/CLI@v1](https://github.com/azure/CLI/tree/v1/) The action executes the Azure CLI Bash script on a user defined Azure CLI version. I have not specified a version, so the latest CLI version is used. The action executes the step in a docker container so we have to pass in the environment variables to the container.

```yml
## ...
    - name: Upload to blob storage
      uses: azure/CLI@v1
      with:
        inlineScript: |
            az storage blob upload-batch --overwrite --account-name ${{ env.storage-account-name }} --auth-mode key -d '$web' -s ${{ env.source-path }}
## ...
```

- Purge CDN endpoint, again this uses GitHub action [azure/CLI@v1](https://github.com/azure/CLI/tree/v1/). The action executes the step in a docker container so we have to pass in the environment variables to the container.

```yml
## ...
    - name: Purge CDN endpoint
      uses: azure/CLI@v1
      with:
        inlineScript: |
          az afd endpoint purge --content-paths  "/*" --profile-name ${{ env.cdn-profile-name }} --endpoint-name ${{ env.cdn-endpoint }} --resource-group ${{ env.resource-group }}
## ...
```



- Azure logout. Logs out of the Azure service principal. if :always ensures the step is run regardless of the outcome of the previous step. There is no way of tampering the credentials or account information because the github hosted runner is on a VM that will get recreated for every workflow run which gets everything deleted. But if the runner is self-hosted which is not GitHub provided it is recommended to manually logout at the end of the workflow as shown. More details on security of the runners can be found [here](https://docs.github.com/en/actions/learn-github-actions/security-hardening-for-github-actions#hardening-for-self-hosted-runners).

```yml
## ...
    - name: Azure logout
      run: |
            az logout
      if: always()
```