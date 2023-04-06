#########################################
# Service creation inside a EKS cluster #
#########################################

locals {
  template_namespace = templatefile("${path.module}/templates/namespace.yaml.tpl", {
    env_name  = var.env_name
    env_owner = var.env_owner
    env_class = var.env_class
  })

  template_tiller = templatefile("${path.module}/templates/tiller.yaml.tpl", {
    docker_registry_secret_name = var.docker_registry_secret_name
  })

  template_metric_server = templatefile("${path.module}/templates/metric-server.yaml.tpl", {
    metric_image                = var.metric_image
    metric_server_version       = var.metric_server_version
    docker_registry_secret_name = var.docker_registry_secret_name
  })

  template_cluster_autoscaler_launch_template = var.worker_group_launch_template_count > 0 ? templatefile("${path.module}/templates/cluster-autoscaler.yaml.tpl", {
    cluster_autoscaler_version  = var.cluster_autoscaler_version
    docker_registry_secret_name = var.docker_registry_secret_name
    cluster_autoscaler_image    = var.cluster_autoscaler_image
    asg_name                    = aws_autoscaling_group.workers_launch_template[0].name
    max_size                    = lookup(var.worker_groups_launch_template[0], "asg_max_size", local.workers_group_launch_template_defaults["asg_max_size"], )
    min_size                    = lookup(var.worker_groups_launch_template[0], "asg_min_size", local.workers_group_launch_template_defaults["asg_min_size"], )
  }) : ""

  template_cluster_autoscaler_launch_configuration = [for n in range(var.worker_group_count) :
    templatefile("${path.module}/templates/cluster-autoscaler.yaml.tpl", {
      cluster_autoscaler_version  = var.cluster_autoscaler_version
      docker_registry_secret_name = var.docker_registry_secret_name
      cluster_autoscaler_image    = var.cluster_autoscaler_image
      asg_name                    = aws_autoscaling_group.workers[0].name
      max_size                    = lookup(var.worker_groups[n], "asg_max_size", local.workers_group_defaults["asg_max_size"], )
      min_size                    = lookup(var.worker_groups[n], "asg_min_size", local.workers_group_defaults["asg_min_size"], )
    })]

  template_cluster_autoscaler_node_group = [for n in range(length(var.node_groups)) : templatefile("${path.module}/templates/cluster-autoscaler.yaml.tpl", {
    cluster_autoscaler_version  = var.cluster_autoscaler_version
    docker_registry_secret_name = var.docker_registry_secret_name
    cluster_autoscaler_image    = var.cluster_autoscaler_image
    asg_name                    = aws_eks_node_group.nodes[n].resources[0].autoscaling_groups[0].name
    max_size                    = lookup(var.node_groups[n], "max_size", local.node_group_launch_template_defaults["asg_max_size"], )
    min_size                    = lookup(var.node_groups[n], "min_size", local.node_group_launch_template_defaults["asg_min_size"], )
  })]

  template_nginx_ingress_controller = templatefile("${path.module}/templates/nginx-ingress-controller.yaml.tpl", {
    nginx_ingress_controller_image   = var.nginx_ingress_controller_image
    nginx_ingress_controller_version = var.nginx_ingress_controller_version
    docker_registry_secret_name      = var.docker_registry_secret_name
  })
}

## 1. Creating docker-registry secret into EKS cluster
## Doc: https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/
resource "null_resource" "docker_registry_secret" {
  count = var.create_docker_registry_secret ? 1 : 0
  depends_on = [
    aws_eks_cluster.this
  ]

  provisioner "local-exec" {
    command     = "for i in `seq 1 10`; do kubectl create secret docker-registry $DOCKER_REGISTRY_SECRET_NAME --docker-server=$DOCKER_REGISTRY_SERVER --docker-username=$DOCKER_USER --docker-password=$DOCKER_PASSWORD --docker-email=$DOCKER_EMAIL -n kube-system --kubeconfig ${var.config_output_path}kubeconfig && exit 0 || sleep 10; done; exit 1"
    interpreter = var.local_exec_interpreter
    environment = {
      DOCKER_REGISTRY_SECRET_NAME = var.docker_registry_secret_name
      DOCKER_REGISTRY_SERVER      = var.docker_registry_server
      DOCKER_USER                 = var.docker_user
      DOCKER_PASSWORD             = var.docker_password
      DOCKER_EMAIL                = var.docker_email
    }
  }
  triggers = {
    endpoint = aws_eks_cluster.this.endpoint
  }
}

## 2. Creating custom namespace into EKS cluster
## Doc: https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/
resource "local_file" "namespace" {
  count    = var.create_ns ? 1 : 0
  content  = local.template_namespace
  filename = "${var.config_output_path}config-namespace_${var.cluster_name}.yaml"
}

resource "null_resource" "creating_namespace" {
  count      = var.create_ns ? 1 : 0
  depends_on = [aws_eks_cluster.this]

  provisioner "local-exec" {
    command     = "for i in `seq 1 10`; do kubectl apply -f ${var.config_output_path}config-namespace_${var.cluster_name}.yaml --kubeconfig ${var.config_output_path}kubeconfig && exit 0 || sleep 10; done; exit 1"
    interpreter = var.local_exec_interpreter
  }

  triggers = {
    config_map_rendered = local.template_namespace
    endpoint            = aws_eks_cluster.this.endpoint
  }
}

## 3. Creating tiller-deploy for deploy applications to EKS cluster via Helm Charts
## Doc: https://helm.sh/docs/intro/install/
resource "local_file" "tiller" {
  count    = var.create_tiller ? 1 : 0
  content  = local.template_tiller
  filename = "${var.config_output_path}config-tiller_${var.cluster_name}.yaml"
}

resource "null_resource" "create_tiller_rbac" {
  count      = var.create_tiller ? 1 : 0
  depends_on = [aws_eks_cluster.this]

  provisioner "local-exec" {
    command     = "for i in `seq 1 10`; do kubectl apply -f ${var.config_output_path}config-tiller_${var.cluster_name}.yaml --kubeconfig ${var.config_output_path}kubeconfig && exit 0 || sleep 10; done; exit 1"
    interpreter = var.local_exec_interpreter
  }

  triggers = {
    config_map_rendered = local.template_tiller
    endpoint            = aws_eks_cluster.this.endpoint
  }
}

resource "null_resource" "install_tiller" {
  count = var.create_tiller ? 1 : 0
  depends_on = [
    null_resource.docker_registry_secret,
    null_resource.create_tiller_rbac
  ]

  provisioner "local-exec" {
    command     = "for i in `seq 1 10`; do helm init --kubeconfig=${var.config_output_path}kubeconfig --service-account tiller --tiller-image ${var.tiller_image} && exit 0 || sleep 10; done; exit 1"
    interpreter = var.local_exec_interpreter
  }

  triggers = {
    config_map_rendered = local.template_tiller
    endpoint            = aws_eks_cluster.this.endpoint
  }
}

## 4. Creating metric-server for basic metrics from deployed applications into EKS
## Doc: https://github.com/kubernetes-sigs/metrics-server
resource "local_file" "metric_server" {
  count    = var.create_metric_server ? 1 : 0
  content  = local.template_metric_server
  filename = "${var.config_output_path}config-metric-server_${var.cluster_name}.yaml"
}

resource "null_resource" "install_metric_server" {
  count = var.create_metric_server ? 1 : 0
  depends_on = [
    aws_eks_cluster.this,
    null_resource.docker_registry_secret
  ]

  provisioner "local-exec" {
    command     = "for i in `seq 1 10`; do kubectl apply -f ${var.config_output_path}config-metric-server_${var.cluster_name}.yaml --kubeconfig ${var.config_output_path}kubeconfig && exit 0 || sleep 10; done; exit 1"
    interpreter = var.local_exec_interpreter
  }

  triggers = {
    config_map_rendered = local.template_metric_server
    endpoint            = aws_eks_cluster.this.endpoint
  }
}

## 5. Creating IAM alb-ingress-controller role
## Doc: https://github.com/kubernetes-sigs/aws-alb-ingress-controller
resource "aws_iam_role_policy_attachment" "workers_alb_ingress_controller" {
  policy_arn = aws_iam_policy.alb_ingress_controller.arn
  role       = aws_iam_role.workers.name
}

resource "aws_iam_role_policy_attachment" "cluster_alb_ingress_controller" {
  policy_arn = aws_iam_policy.alb_ingress_controller.arn
  role       = aws_iam_role.cluster.name
}

## https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json
resource "aws_iam_policy" "alb_ingress_controller" {
  name_prefix = "alb-ingress-controller-${aws_eks_cluster.this.name}"
  description = "AWS ALB ingress policy for cluster ${aws_eks_cluster.this.name}"
  policy      = file("${path.module}/policies/aws_load_balancer_controller_policy.json")
}

## 6. Creating cluster-autoscaler for automatically adjusts the size of the Kubernetes cluster
## Doc: https://github.com/kubernetes/autoscaler/tree/master/cluster-autoscaler

## Cluster autoscaler for Launch Template
resource "local_file" "config_cluster_autoscaler_launch_template" {
  count    = var.worker_group_launch_template_count && var.create_cluster_autoscaler ? 1 : 0
  content  = local.template_cluster_autoscaler_launch_template
  filename = "${var.config_output_path}config-cluster-autoscaler-launch-template_${var.cluster_name}.yaml"
}

resource "null_resource" "install_cluster_autoscaler_launch_template" {
  count = var.worker_group_launch_template_count && var.create_cluster_autoscaler ? 1 : 0

  depends_on = [
    aws_eks_cluster.this,
    null_resource.docker_registry_secret,
    aws_autoscaling_group.workers_launch_template
  ]

  provisioner "local-exec" {
    command     = "for i in `seq 1 10`; do kubectl apply -f ${var.config_output_path}config-cluster-autoscaler-launch-template_${var.cluster_name}.yaml --kubeconfig ${var.config_output_path}kubeconfig && exit 0 || sleep 10; done; exit 1"
    interpreter = var.local_exec_interpreter
  }

  triggers = {
    config_map_rendered = local.template_cluster_autoscaler_launch_template
    endpoint            = aws_eks_cluster.this.endpoint
  }
}

## Cluster autoscaler for Launch Configuration

resource "local_file" "config_cluster_autoscaler_launch_configuration" {
  count    = var.worker_group_count && var.create_cluster_autoscaler ? 1 : 0
  content  = local.template_cluster_autoscaler_launch_configuration[0]
  filename = "${var.config_output_path}config-cluster-autoscaler-launch-configuration_${var.cluster_name}.yaml"
}

resource "null_resource" "install_cluster_autoscaler_launch_configuration" {
  count = var.worker_group_count && var.create_cluster_autoscaler ? 1 : 0

  depends_on = [
    aws_eks_cluster.this,
    null_resource.docker_registry_secret,
    aws_autoscaling_group.workers
  ]

  provisioner "local-exec" {
    command     = "for i in `seq 1 10`; do kubectl apply -f ${var.config_output_path}config-cluster-autoscaler-launch-configuration_${var.cluster_name}.yaml --kubeconfig ${var.config_output_path}kubeconfig && exit 0 || sleep 10; done; exit 1"
    interpreter = var.local_exec_interpreter
  }

  triggers = {
    config_map_rendered = local.template_cluster_autoscaler_launch_configuration[0]
    endpoint            = aws_eks_cluster.this.endpoint
  }
}

## Cluster Autoscaler for Node Group

resource "local_file" "config_cluster_autoscaler_node_group" {
  count    = length(var.node_groups) > 0 && var.create_cluster_autoscaler ? 1 : 0
  content  = local.template_cluster_autoscaler_node_group[0]
  filename = "${var.config_output_path}config-cluster-autoscaler-node-group_${var.cluster_name}.yaml"
}

resource "null_resource" "install_cluster_autoscaler_node_group" {
  count = length(var.node_groups) > 0 && var.create_cluster_autoscaler ? 1 : 0

  depends_on = [
    aws_eks_cluster.this,
    null_resource.docker_registry_secret,
    aws_eks_node_group.nodes
  ]

  provisioner "local-exec" {
    command     = "for i in `seq 1 10`; do kubectl apply -f ${var.config_output_path}config-cluster-autoscaler-node-group_${var.cluster_name}.yaml --kubeconfig ${var.config_output_path}kubeconfig && exit 0 || sleep 10; done; exit 1"
    interpreter = var.local_exec_interpreter
  }

  triggers = {
    config_map_rendered = local.template_cluster_autoscaler_node_group[0]
    endpoint            = aws_eks_cluster.this.endpoint
  }
}

## 7. Creating nginx-ingress-controller for provide load balancing, SSL termination and name-based virtual hosting.
## Doc: https://kubernetes.github.io/ingress-nginx/
resource "local_file" "nginx_ingress_controller" {
  count    = var.create_nginx_ingress_controller ? 1 : 0
  content  = local.template_nginx_ingress_controller
  filename = "${var.config_output_path}config-nginx_ingress_controller_${var.cluster_name}.yaml"
}

resource "null_resource" "install_nginx_ingress_controller" {
  count = var.create_nginx_ingress_controller ? 1 : 0
  depends_on = [
    aws_eks_cluster.this,
    null_resource.docker_registry_secret
  ]

  provisioner "local-exec" {
    command     = "for i in `seq 1 10`; do kubectl apply -f ${var.config_output_path}config-nginx_ingress_controller_${var.cluster_name}.yaml --kubeconfig ${var.config_output_path}kubeconfig && exit 0 || sleep 10; done; exit 1"
    interpreter = var.local_exec_interpreter
  }

  triggers = {
    config_map_rendered = local.template_nginx_ingress_controller
    endpoint            = aws_eks_cluster.this.endpoint
  }
}
