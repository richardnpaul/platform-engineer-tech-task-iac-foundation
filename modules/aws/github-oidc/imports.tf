import {
  to = aws_iam_openid_connect_provider.github
  id = "arn:aws:iam::793421532223:oidc-provider/token.actions.githubusercontent.com"
}

import {
  to = aws_iam_policy.github_actions_boundary
  id = "arn:aws:iam::793421532223:policy/GitHubActionsPermissionsBoundary"
}

import {
  to = aws_iam_role.github_actions
  id = "GitHubActionsDeploymentRole"
}

import {
  to = aws_iam_role_policy.github_actions_deployment
  id = "GitHubActionsDeploymentRole:DeploymentAccess"
}
