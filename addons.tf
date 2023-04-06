#############################################################
# Install EBS CSI driver add-on and attach an IAM role to it
#############################################################

data "aws_iam_policy_document" "eks_ebs_csi_driver" {
  count = var.ebs_csi_driver_addon_enabled ? 1 : 0

  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.this.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
    }

    principals {
      identifiers = [aws_iam_openid_connect_provider.this.arn]
      type        = "Federated"
    }
  }
}

resource "aws_iam_role" "eks_ebs_csi_driver" {
  count              = var.ebs_csi_driver_addon_enabled ? 1 : 0
  name               = "${aws_eks_cluster.this.name}-ebs-csi-driver-role"
  description        = "Role for the Amazon EBS CSI Driver Add-on"
  assume_role_policy = data.aws_iam_policy_document.eks_ebs_csi_driver[0].json

  tags = merge(
    var.common_tags,
    {
      "Name" = "${aws_eks_cluster.this.name}-ebs-csi-driver-role"
    },
  )
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count      = var.ebs_csi_driver_addon_enabled ? 1 : 0
  role       = aws_iam_role.eks_ebs_csi_driver[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

resource "aws_eks_addon" "eks_ebs_csi_driver" {
  count                    = var.ebs_csi_driver_addon_enabled ? 1 : 0
  cluster_name             = aws_eks_cluster.this.name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.ebs_csi_driver_addon_version
  service_account_role_arn = aws_iam_role.eks_ebs_csi_driver[0].arn
}
