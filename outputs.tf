output "cluster_id" {
  description = "The name/id of the EKS cluster."
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "The Amazon Resource Name (ARN) of the cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_certificate_authority_data" {
  description = "Nested attribute containing certificate-authority-data for your cluster. This is the base64 encoded certificate data required to communicate with your cluster."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_endpoint" {
  description = "The endpoint for your EKS Kubernetes API."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_version" {
  description = "The Kubernetes server version for the EKS cluster."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster."
  value       = local.cluster_security_group_id
}

output "config_map_aws_auth" {
  description = "A kubernetes configuration to authenticate to this EKS cluster."
  value       = local.template_config_map_aws_auth
}

#output "kubeconfig" {
#  description = "kubectl config file contents for this EKS cluster."
#  value       = data.local_file.kubectl.content
#}

output "workers_asg_arns" {
  description = "IDs of the autoscaling groups containing workers."
  value = concat(
    aws_autoscaling_group.workers.*.arn,
    aws_autoscaling_group.workers_launch_template.*.arn,
  )
}

output "workers_asg_names" {
  description = "Names of the autoscaling groups containing workers."
  value = concat(
    aws_autoscaling_group.workers.*.id,
    aws_autoscaling_group.workers_launch_template.*.id,
  )
}

output "worker_security_group_id" {
  description = "Security group ID attached to the EKS workers."
  value       = local.worker_security_group_id
}

output "worker_iam_role_name" {
  description = "default IAM role name for EKS worker groups"
  value       = aws_iam_role.workers.name
}

output "worker_iam_role_arn" {
  description = "default IAM role ARN for EKS worker groups"
  value       = aws_iam_role.workers.arn
}

output "identity_oidc" {
  description = "Nested attribute containing identity provider information for your cluster."
  value       = aws_eks_cluster.this.identity.0.oidc.0.issuer
}

output "openid_connect_provider" {
  description = "The ARN assigned by AWS for this provider."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "eks_node_group_asg_name" {
  description = "Name of Autoscaling Group, created automatically for Node Group"
  value = aws_eks_node_group.nodes[*].resources[*].autoscaling_groups[*].name
}
