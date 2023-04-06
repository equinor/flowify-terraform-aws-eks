apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
imagePullSecrets:
  - name: ${docker_registry_secret_name}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: tiller
    namespace: kube-system
