data "aws_region" "current" {}

##################################################################
# Generates an IAM policy document in JSON format for EKS workers
##################################################################

data "aws_iam_policy_document" "workers_assume_role_policy" {
  statement {
    sid = "EKSWorkerAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        "ec2.amazonaws.com",
      ]
    }
  }
}

############################################################
# Get the ID of a registered AMI for use in other resources
############################################################

data "aws_ami" "eks_worker" {
  filter {
    name = "name"

    values = [
      var.custom_ami == "true" ? var.ami_custom_name : local.ami_name_eks,
    ]
  }

  most_recent = true

  owners = [
    var.custom_ami == "true" ? var.ami_custom_owner : var.ami_owner,
  ]
}

data "aws_ami" "eks_node" {
  filter {
    name = "name"

    values = [
      var.custom_ami == "true" ? var.ami_custom_name : local.ami_name_eks,
    ]
  }

  most_recent = true

  owners = [
    var.custom_ami == "true" ? var.ami_custom_owner : var.ami_owner,
  ]
}

##################################################################
# Generates an IAM policy document in JSON format for EKS cluster
##################################################################

data "aws_iam_policy_document" "cluster_assume_role_policy" {
  statement {
    sid = "EKSClusterAssumeRole"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type = "Service"

      identifiers = [
        "eks.amazonaws.com",
      ]
    }
  }
}

###################################################
# The template_file data source renders a template
###################################################
locals {
  template_kubeconfig = templatefile("${path.module}/templates/kubeconfig.tpl", {
    kubeconfig_name                = local.kubeconfig_name
    endpoint                       = aws_eks_cluster.this.endpoint
    region                         = data.aws_region.current.name
    cluster_auth_base64            = aws_eks_cluster.this.certificate_authority[0].data
    aws_authenticator_command      = length(var.kubeconfig_aws_authenticator_command) > 0 ? var.kubeconfig_aws_authenticator_command : "aws"
    aws_authenticator_command_args = length(var.kubeconfig_aws_authenticator_command_args) > 0 ? "        - ${join(
      "\n        - ",
      var.kubeconfig_aws_authenticator_command_args,
      )}" : "        - ${join(
      "\n        - ",
      formatlist("\"%s\"", ["--region", data.aws_region.current.name, "eks", "get-token", "--cluster-name", aws_eks_cluster.this.name,
      "--profile", var.env_class]),
    )}"
    aws_authenticator_additional_args = length(var.kubeconfig_aws_authenticator_additional_args) > 0 ? "        - ${join(
      "\n        - ",
      var.kubeconfig_aws_authenticator_additional_args,
    )}" : ""
    aws_authenticator_env_variables = length(var.kubeconfig_aws_authenticator_env_variables) > 0 ? "      env:\n${join(
      "\n",
      local.template_aws_authenticator_env_variables,
    )}" : ""
  })

  template_aws_authenticator_env_variables = [ for n in range(length(var.kubeconfig_aws_authenticator_env_variables)) :
    templatefile("${path.module}/templates/aws_authenticator_env_variables.tpl", {
      value = element(values(var.kubeconfig_aws_authenticator_env_variables), n, )
      key   = element(keys(var.kubeconfig_aws_authenticator_env_variables), n, )
    })]

  template_userdata = [for n in range(var.worker_group_count) : templatefile("${path.module}/templates/userdata.sh.tpl", {
    cluster_name        = aws_eks_cluster.this.name
    endpoint            = aws_eks_cluster.this.endpoint
    cluster_auth_base64 = aws_eks_cluster.this.certificate_authority[0].data
    pre_userdata        = lookup(var.worker_groups[n], "pre_userdata", local.workers_group_defaults["pre_userdata"], )
    additional_userdata = lookup(var.worker_groups[n], "additional_userdata", local.workers_group_defaults["additional_userdata"], )
    kubelet_extra_args  = lookup(var.worker_groups[n], "kubelet_extra_args", local.workers_group_defaults["kubelet_extra_args"], )
  })]

  template_launch_template_userdata = [for n in range(var.worker_group_launch_template_count) : templatefile("${path.module}/templates/userdata.sh.tpl", {
    cluster_name        = aws_eks_cluster.this.name
    endpoint            = aws_eks_cluster.this.endpoint
    cluster_auth_base64 = aws_eks_cluster.this.certificate_authority[0].data
    pre_userdata        = lookup(var.worker_groups_launch_template[n], "pre_userdata", local.workers_group_defaults["pre_userdata"], )
    additional_userdata = lookup(var.worker_groups_launch_template[n], "additional_userdata", local.workers_group_defaults["additional_userdata"], )
    kubelet_extra_args  = lookup(var.worker_groups_launch_template[n], "kubelet_extra_args", local.workers_group_defaults["kubelet_extra_args"], )
  })]

  template_nodegroup_userdata = [for n in range(length(var.node_groups)) : templatefile("${path.module}/templates/userdata.sh.tpl", {
    cluster_name        = aws_eks_cluster.this.name
    endpoint            = aws_eks_cluster.this.endpoint
    cluster_auth_base64 = aws_eks_cluster.this.certificate_authority[0].data
    pre_userdata        = lookup(var.node_groups[n], "pre_userdata", local.node_group_launch_template_defaults["pre_userdata"], )
    additional_userdata = lookup(var.node_groups[n], "additional_userdata", local.node_group_launch_template_defaults["additional_userdata"], )
    kubelet_extra_args  = lookup(var.node_groups[n], "kubelet_extra_args", local.node_group_launch_template_defaults["kubelet_extra_args"], )
  })]
}
