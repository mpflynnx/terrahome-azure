#!/usr/bin/env bash

# Text formatting
declare red=$(tput setaf 1)
declare bold=$(tput bold)
declare plain=$(tput sgr0)
declare white=$(tput setaf 7)
declare newline=$'\n'

# Element styling
declare errorStyle="${red}${bold}"
declare defaultTextStyle="${plain}${white}"

# AZ CLI check
echo "${newline}Making sure you're signed in to Azure CLI..."
az account show -o none

if [ ! $? -eq 0 ]
then
    exit 1
fi

echo "${newline}Using the following Azure subscription. If this isn't correct, press Ctrl+C and select the correct subscription with \"az account set\""
az account show -o table

# GitHub CLI check
echo "${newline}Making sure you're signed in to GitHub CLI..."
gh auth status

if [ ! $? -eq 0 ]
then
    exit 1
fi

owner=$(gh repo view --json owner -q ".owner.login")

# Repository name is the appName!
appName=$(gh repo view --json name -q ".name")

echo "${newline}Getting credentials from signed in user...${newline}"
azureSubscriptionId=$(az account show --query "id" --output tsv)

az account set -s "${azureSubscriptionId}"

# check for existing app first
clientId=$(az ad app list --display-name "${appName}" --query "[].appId" --output tsv)

if [ -n "${clientId}" ]
then
  echo "${newline}${errorStyle}Application '${appName}' already exists, exiting.${defaultTextStyle}${newline}"
  exit 1
fi

# Create a Microsoft Entra ID application.
echo "${newline}Creating new Microsoft Entra application..."
az ad app create --display-name "${appName}" --output none
if [ ! $? -eq 0 ]
then
  echo "${newline}${errorStyle}ERROR creating application, exiting.${defaultTextStyle}${newline}"
  exit 1
fi

clientId=$(az ad app list --display-name "${appName}" --query "[].appId" --output tsv)
echo "${newline}Application created."
echo "${newline}Application ID: ${clientId}${newline}"

# Create new Service principal

echo "${newline}Creating new Service principal..."
if [ -n "${clientId}" ]
then
  az ad sp create --id "${clientId}" --output none

  if [ ! $? -eq 0 ]
  then
    echo "${newline}${errorStyle}ERROR creating Service principal, exiting.${defaultTextStyle}${newline}"
    # delete app
    az ad app delete --id "${clientId}"
    exit 1
  fi

  echo "${newline}Service principal created.${newline}"

fi

# Get ObjectId of the Service principal
spObjectId=$(az ad sp list --display-name "${appName}" --query "[].id" --output tsv)

# Add role assignment
echo "${newline}Adding new role assignment..."
if [ -n "${spObjectId}" ]
then
  az role assignment create \
    --role "Contributor" \
    --assignee-object-id "${spObjectId}" \
    --assignee-principal-type ServicePrincipal \
    --scope /subscriptions/"${azureSubscriptionId}" \
    --output none

  if [ ! $? -eq 0 ]
  then
    echo "${newline}${errorStyle}ERROR adding role to service principal, exiting.${defaultTextStyle}${newline}"
    # delete app
    az ad app delete --id "${clientId}"
    exit 1
  fi

  echo "${newline}Role added successfully.${newline}"
  
fi

# Create a new federated identity credential
# Needs object id of the app registration not service principal
appObjectId=$(az ad app list --display-name "${appName}" --query "[].id" --output tsv)

# Create credential.json using Heredoc
cat > "credential.json" << EOF
{
    "name": "${appName}",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:${owner}/${appName}:ref:refs/heads/main",
    "description": "${appName}",
    "audiences": [
        "api://AzureADTokenExchange"
    ]
}
EOF

echo "${newline}Adding federated credentials..."
if [ -n "${appObjectId}" ]
then
  az ad app federated-credential create --id "${appObjectId}" --parameters credential.json --output none
  if [ ! $? -eq 0 ]
  then
    echo "${newline}${errorStyle}ERROR adding federated credentials, exiting.${defaultTextStyle}${newline}"
    # delete app
    az ad app delete --id "${clientId}"
    exit 1
  fi

  echo "${newline}Federated credentials added successfully.${newline}"
  
fi

# Cleaning up
rm credential.json 2>/dev/null

echo "${newline}Application created!"
echo "${newline}Application name: ${appName}"
echo "Application ID: ${clientId}${newline}"
