## Setting up GitHub Cli authentication 

 Creating an authentication token for github.com API requests via GitHub Cli avoids being prompted to authenticate GitHub Cli.

### Create a token

- Login to your GitHub.com account.

- Navigate to [Personal access tokens (classic)](https://github.com/settings/tokens) via
Settings / Developer Settings / Personal access tokens / Tokens (classic)

- Click on, Generate new token

- Click on, Generate new token (classic) For general use

- Confirm Access follow the in screen prompts

- Add a Note describe what the token is used for. i.e github cli

- Set Expiration 30 days

- Select scopes:
Select the scopes for the token: "repo", "read:org" and workflow.

- Click Generate token

- Copy the token to clipboard

- Create a new environmental variable for the token, and paste into the linux command shown below.

```bash
export GITHUB_TOKEN="paste token here"
```

If using Gitpod, to persist variable in new Gitpod workspaces. 

```bash
gp env GITHUB_TOKEN="paste token here"
```
