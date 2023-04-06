resource "local_file" "config_map_aws_auth" {
  content  = local.template_config_map_aws_auth
  filename = "${var.config_output_path}config-map-aws-auth_${var.cluster_name}.yaml"
  count    = var.manage_aws_auth ? 1 : 0
}

resource "null_resource" "update_config_map_aws_auth" {
  depends_on = [aws_eks_cluster.this]

  provisioner "local-exec" {
    command     = "for i in `seq 1 10`; do kubectl apply -f ${var.config_output_path}config-map-aws-auth_${var.cluster_name}.yaml --kubeconfig ${var.config_output_path}kubeconfig && exit 0 || sleep 10; done; exit 1"
    interpreter = var.local_exec_interpreter
  }

  triggers = {
    config_map_rendered  = local.template_config_map_aws_auth
    endpoint = aws_eks_cluster.this.endpoint
  }

  count = var.manage_aws_auth ? 1 : 0
}

data "aws_caller_identity" "current" {
}

locals {
  template_config_map_aws_auth = templatefile("${path.module}/templates/config-map-aws-auth.yaml.tpl", {
    nodegroup_role_arn = join("", [
      for n in range(length(var.node_groups)) : templatefile("${path.module}/templates/nodegroup-role.tpl", {
        nodegroup_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${element(aws_iam_role.eks_node_group_role.*.name, n)}"
      })
    ])
    worker_role_arn = join("", distinct(
      concat(
        [for n in range(var.worker_group_launch_template_count) : templatefile("${path.module}/templates/worker-role.tpl", {
          worker_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${element(aws_iam_instance_profile.workers_launch_template.*.role, n, )}"
        })],
        [for n in range(var.worker_group_count) : templatefile("${path.module}/templates/worker-role.tpl", {
          worker_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${element(aws_iam_instance_profile.workers.*.role, n)}"
        })]
      )
    ))
    map_users = join("", [
      for n in range(var.map_users_count) :
      templatefile("${path.module}/templates/config-map-aws-auth-map_users.yaml.tpl", {
        user_arn = var.map_users[n]["user_arn"],
        username = var.map_users[n]["username"],
        group    = var.map_users[n]["group"]
      })
    ])
    map_roles = join("", [
      for n in range(var.map_roles_count) :
      templatefile("${path.module}/templates/config-map-aws-auth-map_roles.yaml.tpl", {
        role_arn = var.map_roles[n]["role_arn"],
        username = var.map_roles[n]["username"],
        group    = var.map_roles[n]["group"]
      })
    ])
    map_accounts = join("", [
      for n in range(var.map_accounts_count) :
      templatefile("${path.module}/templates/config-map-aws-auth-map_accounts.yaml.tpl", {
        account_number = element(var.map_accounts, n)
      })
    ])
  })
}
