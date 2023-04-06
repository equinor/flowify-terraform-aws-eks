apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
${nodegroup_role_arn}
${worker_role_arn}
${map_roles}
  mapUsers: |
${map_users}
  mapAccounts: |
${map_accounts}
