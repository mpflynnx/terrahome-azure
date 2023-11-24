## Azure new user creation

When an Azure account is created we have a subscription. We also have something called a [Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/fundamentals/whatis) Default Directory (Tenant). As the first user you are assigned the [Global Administrator role](https://learn.microsoft.com/en-us/entra/identity/role-based-access-control/permissions-reference#global-administrator). As the name suggests, this user has access to everything and can do everything.

Within the Default Directory, we can [register applications](https://learn.microsoft.com/en-gb/entra/identity-platform/app-objects-and-service-principals?tabs=browser#application-registration) like Terraform and assign them roles to allow creation or modification of Azure resources.

For development, is it best practice to create a new user and assign less privileged roles. This user can then be used for everyday development tasks. The role given to this user is usually 'Contributor'. The [Contributor role](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#contributor) is a built-in role in Azure that allows a user to create and manage all types of Azure resources, but not grant access to others. This role can be assigned to a user at the subscription or resource group level, depending on the scope of permissions needed.

As I will be using this new user to create a service principal for the GitHub action workflow, I need to assign another role. That of [Role Based Access Control Administrator](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#role-based-access-control-administrator-preview). It is a built-in role in Azure that allows a user to manage access to Azure resources by assigning roles using Azure RBAC. This role does not allow management access using other ways, such as Azure Policy. 

I have created a bash script [new-azure-user.sh](../bin/new-azure-user.sh) to aid in the creation of a new user in Azure with the roles needed. The script depends on Azure CLI being installed and ready for use. I recommend using Gitpod along with this repository. I have created a '.gitpod.yml' file  and bash scripts in this repository that will install the latest versions of Azure CLI in the Gitpod cloud development environment. For instructions on how to use Gitpod refer to document [Gitpod Development Environment](gitpod-development-environment.md).

#### Running the script

The script requires a signed in user to Azure Cli.

The script requires one argument. This is the name you want to give the user. In the example below the user name given is 'developer01'.

#### Usage example
```bash
$ ./bin/new-azure-user.sh developer01
```

### Review of the 'new-azure-user.sh' bash script

The first lines of the script are for formatting the messages displayed.

```bash
## ...

# Text formatting
declare red=$(tput setaf 1)
declare bold=$(tput bold)
declare plain=$(tput sgr0)
declare white=$(tput setaf 7)
declare newline=$'\n'

# Element styling
declare errorStyle="${red}${bold}"
declare defaultTextStyle="${plain}${white}"

## ...
```

The first argument passed to the script, should be a username for the user. The script requires this name to be lowercase letters with or without numbers, but no spaces. I check the first argument is passed to the script. If the argument is empty, it prints an error message and usage example, then the scripts exits. I assign the argument value to variable displayName for use later.

```bash
## ...

if [ -z "$1" ]; then
  echo "${newline}${errorStyle}ERROR, please define a username (mix lowercase letters or numbers, no spaces).${defaultTextStyle}${newline}"
  echo "Usage example: $ $0 developer01${newline}"
  exit 1
fi

displayName="$1"

## ...
```

I use the [az account show](https://learn.microsoft.com/en-us/cli/azure/account?view=azure-cli-latest#az-account-show) command with an output parameter set to none. If this command returns an error it means that Azure CLI is not available and the script will exit.

```bash
## ...

# AZ CLI check
echo "Making sure you're signed in to Azure CLI..."
az account show -o none

if [ ! $? -eq 0 ]
then
    exit 1
fi

## ...
```

Then, I get the default subscription of the signed in user by using the [az account show](https://learn.microsoft.com/en-us/cli/azure/account?view=azure-cli-latest#az-account-show) command with an output parameter set to table. 

```bash
## ...

az account show -o table

## ...
```

I store the default subscription ID of the signed in user into a local variable by using the [az account show](https://learn.microsoft.com/en-us/cli/azure/account?view=azure-cli-latest#az-account-show) command with a query of the TSV outputs "id" field. 

```bash
## ...

azureSubscriptionId=$(az account show --query "id" --output tsv)

## ...
```

I then use [az account set](https://learn.microsoft.com/en-us/cli/azure/account?view=azure-cli-latest#az-account-set) to set the currently selected Azure subscription.

```bash
## ...

az account set -s "${azureSubscriptionId}"

## ...
```

Then, I need to check that the Microsoft Entra ID user doesn't already exist, by using the Azure CLI command [az ad user list](https://learn.microsoft.com/en-us/cli/azure/ad/user?view=azure-cli-latest#az-ad-user-list).

I assign the output of the command to a local variable 'userObjectId'.

If the 'userObjectId' variable has a value that means the user already exists, and the script exits.

```bash
## ...

userObjectId=$(az ad user list --display-name "${displayName}" --query "[].id" --output tsv)

if [ -n "${userObjectId}" ]
then
  echo "${newline}${errorStyle}User '${displayName}' already exists, exiting.${newline}${defaultTextStyle}"
  exit 1
fi

## ...
```

To create a new user, I need to provide a user principal name. This should contain the default directory primary domain name. To obtain the primary domain name of the default directory, I use the [Azure REST API](https://learn.microsoft.com/en-us/rest/api/azure/). This command will return a JSON object containing the 'id' of the primary domain. I pipe the output into the 'jq' linux command to extract the 'id' field from the JSON object. The '-r' flag is used to output the result in raw format, without quotes. I store this in local variable 'primaryDomain'.

```bash
## ...

primaryDomain=$(az rest --method get --url 'https://graph.microsoft.com/v1.0/domains?$select=id' | jq -r '.value[0].id')

## ...
```

I then build the user principal name using the local variables 'displayName' and 'primaryDomain'.

```bash
## ...

userPrincipalName="${displayName}@${primaryDomain}"

## ...
```

I need to provide a first login password for the new user. The user will be prompted to change this at first login. This password will not be very secure, but sufficient to pass the password policy requirements. I use the linux commands 'urandom' and 'head' to create variables for the front and rear of the password. I then combine them into one password variable.

```bash
## ...

# generate an initial password, user will be forced to change this
PasswdFront=$(</dev/urandom tr -dc 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz' | head -c4; echo "")
PasswdRear=$(</dev/urandom tr -dc '1234567890' | head -c6; echo "")
initialPasswd="${PasswdFront}a!B${PasswdRear}"

## ...
```

Continuing on. I can now create a new user using the [az ad user create](https://learn.microsoft.com/en-us/cli/azure/ad/user?view=azure-cli-latest#az-ad-user-create) command and pass in the required parameter values. If this command returns an error the script will exit.

```bash
## ...

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

## ...
```

Then, I need to assign the roles to the new user. I first get the object ID of the new user using command [az ad user list](https://learn.microsoft.com/en-us/cli/azure/ad/user?view=azure-cli-latest#az-ad-user-list) and assign the Id to variable 'userObjectId'.

```bash
## ...

userObjectId=$(az ad user list --display-name "${displayName}" --query "[].id" --output tsv)

## ...
```

For each role assignment I need to define the scope of the role for the user. This can be the subscription or more granular, down to a resource group or resource. I assign the scope to a variable 'userScope'.

```bash
## ...

userScope="/subscriptions/${azureSubscriptionId}"

## ...
```

As I need to define multiple roles. I shall create an array called 'roles'. I will then loop through the array and create a new role using command [az role assignment create](https://learn.microsoft.com/en-us/cli/azure/role/assignment?view=azure-cli-latest#az-role-assignment-create). If  the role assignment fails then the user is deleted and the script exits.

```bash
## ...

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

## ...
```

Finally I print the new users role assignments the object ID, user login and password.

```bash
## ...

echo "${newline}User role assignments:-"
az role assignment list --assignee "${userObjectId}" --query "[].roleDefinitionName" --output tsv
echo "${newline}"

echo "Object Id: ${userObjectId}"
echo "User login: ${userPrincipalName}"
echo "Password: ${initialPasswd}${newline}"

## ...
```

You should now logout and login as the new user, when prompted change the password and setup two factor authentication.

```bash
az logout

az login --use-device-code
```