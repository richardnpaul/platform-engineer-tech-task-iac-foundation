# Notes:

## Manual Steps (ClickOps)

### AWS

#### Post Account creation

There are some best practice operations which don't have an alternative to ClickOps, unfortunately:

- Set up MFA for the root user account
- You will need to manually trigger control tower setup as there's no way to do this via cli/api
- You will need to manually trigger SSO setup for a region as there's no way to do this via the cli/api
