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

if [ -z "$1" ]; then
  echo "${newline}${errorStyle}ERROR, please define a username (mix lowercase letters or numbers, no spaces).${defaultTextStyle}${newline}"
  echo "Usage example: $ $0 developer01${newline}"
  exit 1
fi

displayName="$1"

# AZ CLI check
echo "${newline}Making sure you're signed in to Azure CLI..."
az account show -o none
echo "${newline}"

if [ ! $? -eq 0 ]
then
    exit 1
fi

echo "Using the following Azure subscription. If this isn't correct, press Ctrl+C and select the correct subscription with \"az account set\""
echo "${newline}"
az account show -o table
echo "${newline}"
sleep 4

echo "${newline}Getting credentials from signed in user...${newline}"
azureSubscriptionId=$(az account show --query "id" --output tsv)

az account set -s "${azureSubscriptionId}"

# Create an Microsoft Entra ID User

# check for existing user first
userObjectId=$(az ad user list --display-name "${displayName}" --query "[].id" --output tsv)

if [ -n "${userObjectId}" ]
then
  echo "${newline}${errorStyle}User '${displayName}' already exists, exiting.${newline}${defaultTextStyle}"
  exit 1
fi

primaryDomain=$(az rest --method get --url 'https://graph.microsoft.com/v1.0/domains?$select=id' | jq -r '.value[0].id')

# build user-principal-name
userPrincipalName="${displayName}@${primaryDomain}"

# generate an initial password, user will be forced to change this
PasswdFront=$(</dev/urandom tr -dc 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' | head -c4; echo "")
PasswdRear=$(</dev/urandom tr -dc '1234567890' | head -c6; echo "")
initialPasswd="${PasswdFront}a!B${PasswdRear}"

echo "${newline}Creating new Microsoft Entra ID User..."
if [ -z "${userObjectId}" ]
then
  az ad user create \
    --display-name "${displayName}" \
    --password "${initialPasswd}" \
    --user-principal-name "${userPrincipalName}" \
    --force-change-password-next-sign-in \
    --output none

  if [ ! $? -eq 0 ]
  then
    echo "${newline}${errorStyle}ERROR creating new user, exiting.${defaultTextStyle}${newline}"
    exit 1
  fi

echo "${newline}User created.${newline}"
 
fi

# Get ObjectId of the User
userObjectId=$(az ad user list --display-name "${displayName}" --query "[].id" --output tsv)

userScope="/subscriptions/${azureSubscriptionId}"

# Add role to new user
roles=("Contributor" "Role Based Access Control Administrator")

for role in "${roles[@]}"
do
  if [ -n "${userObjectId}" ]
  then
    az role assignment create \
      --assignee-object-id "${userObjectId}" \
      --assignee-principal-type User \
      --role "${role}" \
      --scope "${userScope}" \
      --output none

    if [ ! $? -eq 0 ]
    then
      echo "${newline}${errorStyle}ERROR adding role to User, exiting.${defaultTextStyle}${newline}"
      # delete User
      az ad user delete --id "${userObjectId}"
      exit 1
    fi

    echo "${newline}Role '${role}' added successfully.${newline}"
  
  fi
done

# list roles
echo "${newline}User role assignments:-"
az role assignment list --assignee "${userObjectId}" --query "[].roleDefinitionName" --output tsv
echo "${newline}"

echo "Object Id: ${userObjectId}"
echo "User login: ${userPrincipalName}"
echo "Password: ${initialPasswd}${newline}"