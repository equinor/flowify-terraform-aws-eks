resource "aws_iam_policy" "eks_node_group_asg_policy" {
  count = length(var.node_groups) > 0 ? 1 : 0 
  name = var.eks_node_group_asg_policy_name
  path = "/"
  description = "Policy with permissions for ASG"
  policy = file("${path.module}/policies/eks_node_group_asg_policy.json")
}

resource "aws_iam_policy" "eks_external_dns_policy" {
  count = length(var.node_groups) > 0 ? 1 : 0
  name = var.eks_external_dns_policy_name != null ? var.eks_external_dns_policy_name : "${var.env_name}-${var.env_class}-AllowExternalDNSUpdates"
  path = "/"
  description = "Policy with permissions for ASG"
  policy = file("${path.module}/policies/eks_external_dns_policy.json")
}

resource "aws_iam_role" "eks_node_group_role" {
  name               = var.eks_node_group_role_name
  count              = length(var.node_groups)
  description        = "Role for the EKS node group"
  assume_role_policy = var.eks_node_group_role_policy_document_json

  tags = merge(
    var.common_tags,
    {
      "Name" = var.eks_node_group_role_name
    },
  )
}

resource "aws_iam_role_policy_attachment" "eks_node_group_policy_attachment" {
  count      = length(var.node_groups) > 0 ? 6 : 0
  role       = aws_iam_role.eks_node_group_role[0].name
  policy_arn = element(["arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
                "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
                "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
                aws_iam_policy.eks_node_group_asg_policy[0].arn,
                aws_iam_policy.eks_external_dns_policy[0].arn,
                aws_iam_policy.alb_ingress_controller.arn], count.index)
}

resource "aws_iam_role_policy_attachment" "eks_helm_policy_attachment" {
  count      = length(var.node_groups) > 0 && length(var.helm_assume_role_arn_list) > 0 ? 1 : 0
  policy_arn = aws_iam_policy.helm[0].arn
  role       = aws_iam_role.eks_node_group_role[0].name
}

resource "aws_eks_node_group" "nodes" {

  count = length(var.node_groups)

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = var.node_groups[count.index].name

#  node_role_arn = var.node_groups[count.index].role_arn[0]
  node_role_arn = aws_iam_role.eks_node_group_role[0].arn
  subnet_ids    = var.subnets

  scaling_config {
    desired_size = var.node_groups[count.index].desired_size
    max_size     = var.node_groups[count.index].max_size
    min_size     = var.node_groups[count.index].min_size
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [scaling_config[0].desired_size]
  }

  launch_template {
    version = element(aws_launch_template.node_groups.*.latest_version, count.index)
    id = element(aws_launch_template.node_groups.*.id, count.index)
  }

  tags = merge(
  {
    "Name" = var.node_groups[count.index].name
  },
  var.common_tags
  )
}


resource "aws_launch_template" "node_groups" {
  name_prefix = "${aws_eks_cluster.this.name}-${lookup(var.node_groups[count.index], "name", count.index, )}"

  image_id      = coalesce(lookup(var.node_groups[count.index], "ami_id", null), local.node_group_launch_template_defaults["ami_id"])
  instance_type = coalesce(lookup(var.node_groups[count.index], "instance_type", null), local.node_group_launch_template_defaults["instance_type"])
  key_name      = coalesce(lookup(var.node_groups[count.index], "key_name", null), local.node_group_launch_template_defaults["key_name"])
  user_data     = base64encode(element(local.template_nodegroup_userdata, count.index, ), )
  ebs_optimized = coalesce(lookup(var.node_groups[count.index], "ebs_optimized", null), lookup(local.ebs_optimized, coalesce(lookup(var.node_groups[count.index], "instance_type", null), local.node_group_launch_template_defaults["instance_type"]), false))
  count         = length(var.node_groups)

  network_interfaces {
    associate_public_ip_address = coalesce(lookup(var.node_groups[count.index], "public_ip", local.node_group_launch_template_defaults["public_ip"], ), "false")
    security_groups             = compact(flatten([local.node_security_group_id, var.node_additional_security_group_ids, var.node_additional_security_group_ids, coalescelist(lookup(var.node_groups[count.index], "additional_security_group_ids", []), local.node_group_launch_template_defaults["additional_security_group_ids"], [""])]))
  }

#  iam_instance_profile {
#    name = var.node_groups[count.index].role_name
#  }

  monitoring {
    enabled = coalesce(lookup(var.node_groups[count.index], "enable_monitoring", local.node_group_launch_template_defaults["enable_monitoring"], ), true)
  }

  placement {
    tenancy = coalesce(lookup(var.node_groups[count.index], "placement_tenancy", local.node_group_launch_template_defaults["placement_tenancy"], ), "default")
  }

  lifecycle {
    create_before_destroy = true
  }

  block_device_mappings {
    device_name = data.aws_ami.eks_node.root_device_name

    ebs {
      volume_size           = lookup(var.node_groups[count.index], "root_volume_size", local.node_group_launch_template_defaults["root_volume_size"], )
      volume_type           = lookup(var.node_groups[count.index], "root_volume_type", local.node_group_launch_template_defaults["root_volume_type"], )
      iops                  = lookup(var.node_groups[count.index], "root_iops", local.node_group_launch_template_defaults["root_iops"], )
      delete_on_termination = true
    }
  }
  tag_specifications {
    resource_type = "volume"

    tags = merge(
    {
      "Name" = "${aws_eks_cluster.this.name}-${lookup(var.node_groups[count.index], "name", count.index, )}-eks_asg"
    },
    var.common_tags,
    )
  }
  tags = merge(
  {
    "Name" = "${aws_eks_cluster.this.name}-${lookup(var.node_groups[count.index], "name", count.index, )}-eks_asg"
  },
  var.common_tags,
  )
}

####################################
# Provides a Workers Security Group
####################################

resource "aws_security_group" "nodes" {
  name_prefix = aws_eks_cluster.this.name
  description = "Security group for all nodes in the cluster."
  vpc_id      = var.vpc_id
  count       = var.node_create_security_group ? 1 : 0
  tags = merge(
  var.common_tags,
  {
    "Name"                                               = "${aws_eks_cluster.this.name}-eks-node-sg"
    "kubernetes.io/cluster/${aws_eks_cluster.this.name}" = "owned"
  },
  )
}

##########################################
# Provides a Workers Security Group rules
##########################################

resource "aws_security_group_rule" "nodes_egress_internet" {
  description       = "Allow nodes all egress to the Internet."
  protocol          = "-1"
  security_group_id = aws_security_group.nodes[0].id
  cidr_blocks       = ["0.0.0.0/0"]
  from_port         = 0
  to_port           = 0
  type              = "egress"
  count             = var.node_create_security_group ? 1 : 0
}

resource "aws_security_group_rule" "nodes_ingress_self" {
  description              = "Allow node to communicate with each other."
  protocol                 = "-1"
  security_group_id        = aws_security_group.nodes[0].id
  source_security_group_id = aws_security_group.nodes[0].id
  from_port                = 0
  to_port                  = 65535
  type                     = "ingress"
  count                    = var.node_create_security_group ? 1 : 0
}

resource "aws_security_group_rule" "nodes_ingress_cluster" {
  description              = "Allow nodes Kubelets and pods to receive communication from the cluster control plane."
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nodes[0].id
  source_security_group_id = local.cluster_security_group_id
  from_port                = var.node_sg_ingress_from_port
  to_port                  = 65535
  type                     = "ingress"
  count                    = var.node_create_security_group ? 1 : 0
}

resource "aws_security_group_rule" "nodes_ingress_cluster_https" {
  description              = "Allow pods running extension API servers on port 443 to receive communication from cluster control plane."
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nodes[0].id
  source_security_group_id = local.cluster_security_group_id
  from_port                = 443
  to_port                  = 443
  type                     = "ingress"
  count                    = var.node_create_security_group ? 1 : 0
}

resource "aws_security_group_rule" "nodes_ingress_rules" {
  for_each                 = var.node_create_security_group ? var.eks_security_group_ingress_rules : {}
  description              = each.value["description"]
  protocol                 = each.value["protocol"]
  security_group_id        = aws_security_group.nodes[0].id
  from_port                = each.value["port"]
  to_port                  = each.value["port"]
  cidr_blocks              = each.value["cidr_blocks"]
  type                     = "ingress"
}
