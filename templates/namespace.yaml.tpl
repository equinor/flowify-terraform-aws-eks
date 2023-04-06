apiVersion: v1
kind: Namespace
metadata:
  annotations:
    "app.kubernetes.io/env-name": ${env_name}
    "app.kubernetes.io/env-owner": ${env_owner}
    "app.kubernetes.io/env-class": ${env_class}
    "app.kubernetes.io/managed-by": "Terraform"
  name: ${env_name}-${env_class}
  labels:
    "app.kubernetes.io/env-name": ${env_name}
    "app.kubernetes.io/env-owner": ${env_owner}
    "app.kubernetes.io/env-class": ${env_class}
    "app.kubernetes.io/managed-by": "Terraform"
