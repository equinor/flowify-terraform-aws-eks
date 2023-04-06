#####################################
# EKS Terraform Module              #
# Valid for both Tf 0.12.29 and 1.0 #
#####################################

#########################
# Manages an EKS Cluster
#########################

resource "aws_eks_cluster" "this" {
  name                      = var.cluster_name
  role_arn                  = join("", aws_iam_role.cluster.*.arn)
  version                   = var.cluster_version
  enabled_cluster_log_types = var.enabled_cluster_log_types

  vpc_config {
    security_group_ids      = [local.cluster_security_group_id]
    subnet_ids              = var.subnets
    endpoint_private_access = var.cluster_private_access
    endpoint_public_access  = var.cluster_public_access
  }

  timeouts {
    create = var.cluster_create_timeout
    delete = var.cluster_delete_timeout
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.cluster_AmazonEKSServicePolicy,
  ]

  tags = merge(
    {
      "Name" = format("%s", var.cluster_name)
    },
    var.common_tags
  )
}

##########################################
# Enabling IAM Roles for Service Accounts
##########################################

## TODO Temporary workaround to make terraform automatically retrieve thumbprint from external script.
## TODO https://github.com/terraform-providers/terraform-provider-aws/issues/10104
data "external" "thumbprint" {
  program     = ["${path.module}/scripts/thumbprint.sh", data.aws_region.current.name]
}

resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.external.thumbprint.result.thumbprint]
  url             = aws_eks_cluster.this.identity.0.oidc.0.issuer
}

####################################
# Provides a Cluster Security Group
####################################

resource "aws_security_group" "cluster" {
  name_prefix = var.cluster_name
  description = "EKS cluster security group."
  vpc_id      = var.vpc_id
  tags = merge(
    var.common_tags,
    {
      "Name" = "${var.cluster_name}-eks-cluster-sg"
    },
  )
  count = var.cluster_create_security_group ? 1 : 0
}

##########################################
# Provides a Cluster Security Group rules
##########################################

resource "aws_security_group_rule" "cluster_egress_internet" {
  description       = "Allow cluster egress access to the Internet."
  protocol          = "-1"
  security_group_id = aws_security_group.cluster[0].id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  type              = "egress"
  count             = var.cluster_create_security_group ? 1 : 0
}

resource "aws_security_group_rule" "cluster_https_worker_ingress" {
  description              = "Allow pods to communicate with the EKS cluster API."
  protocol                 = "tcp"
  security_group_id        = aws_security_group.cluster[0].id
  cidr_blocks              = var.allowed_cidr_block
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
  count                    = var.cluster_create_security_group ? 1 : 0
}

#######################################
# Provides an IAM role for EKS cluster
#######################################

resource "aws_iam_role" "cluster" {
  name_prefix           = var.cluster_name
  assume_role_policy    = data.aws_iam_policy_document.cluster_assume_role_policy.json
  force_detach_policies = true
  tags                  = var.common_tags
}

###############################################################
# Attaches a Managed IAM Policy to an IAM role for EKS cluster
###############################################################

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSServicePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy"
  role       = aws_iam_role.cluster.name
}

