variable "region" {
  type        = string
  default     = "us-west-2"
  description = "The region where AWS operations will take place"
}

variable "env_name" {
  type        = string
  default     = "usw201"
  description = "Environment name to be used on all the resources as identifier"
}

variable "env_owner" {
  type        = string
  default     = "DevOps"
  description = "The environment owner tag that will be added to all taggable resources"
}

variable "env_class" {
  type        = string
  default     = "dev"
  description = "The environment class tag that will be added to all taggable resources"
}

variable "common_tags" {
  type        = map(string)
  description = "The default tags that will be added to all taggable resources"

  default = {
    EnvClass    = "dev"
    Environment = "Playground"
    Owner       = "Ops"
    Terraform   = "true"
  }
}

variable "cluster_name" {
  type        = string
  default     = "atlas"
  description = "Name of the EKS cluster. Also used as a prefix in names of related resources."
}

variable "cluster_security_group_id" {
  type        = string
  default     = ""
  description = "If provided, the EKS cluster will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the workers and provide API access to your current IP/32."
}

variable "cluster_version" {
  type        = string
  default     = "1.24"
  description = "Kubernetes version to use for the EKS cluster."
}

variable "config_output_path" {
  type        = string
  default     = "./"
  description = "Where to save the Kubectl config file (if `write_kubeconfig = true`). Should end in a forward slash `/` ."
}

variable "write_kubeconfig" {
  default     = true
  description = "Whether to write a Kubectl config file containing the cluster configuration. Saved to `config_output_path`."
}

variable "manage_aws_auth" {
  default     = true
  description = "Whether to write and apply the aws-auth configmap file."
}

variable "map_accounts" {
  type        = list(string)
  default     = []
  description = "Additional AWS account numbers to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format."
}

variable "map_accounts_count" {
  type        = string
  default     = 0
  description = "The count of accounts in the map_accounts list."
}

variable "map_roles" {
  type        = list(any)
  default     = []
  description = "Additional IAM roles to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format."
}

variable "map_roles_count" {
  description = "The count of roles in the map_roles list."
  type        = string
  default     = 0
}

variable "map_users" {
  type        = list(any)
  default     = []
  description = "Additional IAM users to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format."
}

variable "map_users_count" {
  type        = string
  default     = 0
  description = "The count of roles in the map_users list."
}

variable "subnets" {
  type        = list(string)
  description = "A list of subnets to place the EKS cluster and workers within."
}

variable "vpc_id" {
  description = "VPC where the cluster and workers will be deployed."
}

variable "worker_groups" {
  description = "A list of maps defining worker group configurations to be defined using AWS Launch Configurations. See workers_group_defaults for valid keys."
  type        = list(any)

  default = [
    {
      name = "default"
    },
  ]
}

variable "worker_group_count" {
  type        = string
  default     = "1"
  description = "The number of maps contained within the worker_groups list."
}

variable "workers_group_defaults" {
  type        = map(string)
  default     = {}
  description = "Override default values for target groups. See workers_group_defaults_defaults in locals.tf for valid keys."
}

variable "worker_groups_launch_template" {
  description = "A list of maps defining worker group configurations to be defined using AWS Launch Templates. See workers_group_defaults for valid keys."
  type        = list(any)

  default = [
    {
      name = "default"
    },
  ]
}

variable "worker_group_launch_template_count" {
  type        = string
  default     = "0"
  description = "The number of maps contained within the worker_groups_launch_template list."
}

variable "workers_group_launch_template_defaults" {
  type        = map(string)
  default     = {}
  description = "Override default values for target groups. See workers_group_defaults_defaults in locals.tf for valid keys."
}

variable "worker_security_group_id" {
  type        = string
  default     = ""
  description = "If provided, all workers will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the EKS cluster."
}

variable "worker_additional_security_group_ids" {
  type        = list(string)
  default     = []
  description = "A list of additional security group ids to attach to worker instances"
}

variable "worker_sg_ingress_from_port" {
  type        = string
  default     = "1025"
  description = "Minimum port number from which pods will accept communication. Must be changed to a lower value if some pods in your cluster will expose a port lower than 1025 (e.g. 22, 80, or 443)."
}

variable "kubeconfig_aws_authenticator_command" {
  type        = string
  default     = "aws"
  description = "Command to use to fetch AWS EKS credentials."
}

variable "kubeconfig_aws_authenticator_command_args" {
  type        = list(string)
  default     = []
  description = "Default arguments passed to the authenticator command. Defaults to [token -i $cluster_name]."
}

variable "kubeconfig_aws_authenticator_additional_args" {
  type        = list(string)
  default     = []
  description = "Any additional arguments to pass to the authenticator such as the role to assume. e.g. [\"-r\", \"MyEksRole\"]."
}

variable "kubeconfig_aws_authenticator_env_variables" {
  description = "Environment variables that should be used when executing the authenticator. e.g. { AWS_PROFILE = \"eks\"}."
  type        = map(string)
  default = {
  }
}

variable "kubeconfig_name" {
  type        = string
  default     = ""
  description = "Override the default name used for items kubeconfig."
}

variable "cluster_create_timeout" {
  type        = string
  description = "Timeout value when creating the EKS cluster."
  default     = "15m"
}

variable "cluster_delete_timeout" {
  type        = string
  description = "Timeout value when deleting the EKS cluster."
  default     = "15m"
}

variable "local_exec_interpreter" {
  description = "Command to run for local-exec resources. Must be a shell-style interpreter. If you are on Windows Git Bash is a good choice."
  type        = list(string)
  default     = ["/bin/sh", "-c"]
}

variable "cluster_create_security_group" {
  description = "Whether to create a security group for the cluster or attach the cluster to `cluster_security_group_id`."
  default     = true
}

variable "worker_create_security_group" {
  description = "Whether to create a security group for the workers or attach the workers to `worker_security_group_id`."
  default     = true
}

variable "worker_ami_name_filter" {
  type        = string
  default     = "v*"
  description = "Additional name filter for AWS EKS worker AMI. Default behaviour will get latest for the cluster_version but could be set to a release from amazon-eks-ami, e.g. \"v20190220\""
}

variable "ami_name_eks" {
  type        = string
  default     = "amazon-eks-node"
  description = "Amazon EKS node AMI name"
}

variable "ami_custom_name" {
  type        = string
  default     = ""
  description = "Custom AMI name"
}

variable "custom_ami" {
  type        = string
  default     = "false"
  description = "Whether to create EKS cluster from custom AMI name"
}

variable "ami_custom_owner" {
  type        = string
  default     = ""
  description = "Owner ID for custom AMI"
}

variable "ami_owner" {
  type        = string
  default     = "602401143452"
  description = "Owner ID for Amazon EKS node AMI"
}

variable "enabled_cluster_log_types" {
  type        = list(string)
  default     = ["api", "audit"]
  description = "A list of the desired control plane logging to enable. For more information, see https://docs.aws.amazon.com/en_us/eks/latest/userguide/control-plane-logs.html. Possible values [`api`, `audit`, `authenticator`, `controllerManager`, `scheduler`]"
}

variable "cluster_private_access" {
  default     = false
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled."
}

variable "cluster_public_access" {
  default     = true
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled."
}

variable "health_check_grace_period" {
  type        = string
  default     = "60"
  description = "Time (in seconds) after instance comes into service before checking health"
}

variable "default_cooldown" {
  type        = string
  default     = "60"
  description = "The amount of time, in seconds, after a scaling activity completes before another scaling activity can start"
}

variable "enabled_metrics" {
  type        = list(string)
  default     = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupPendingInstances", "GroupStandbyInstances", "GroupTerminatingInstances", "GroupTotalInstances"]
  description = "A list of metrics to collect"
}

variable "helm_repository_name" {
  type        = string
  default     = "stable"
  description = "Helm repository name (stable , incubator)"
}

variable "helm_repository_url" {
  type        = string
  default     = "https://kubernetes-charts.storage.googleapis.com"
  description = "Helm repository url (https://kubernetes-charts.storage.googleapis.com , https://kubernetes-charts-incubator.storage.googleapis.com)"
}

variable "create_ns" {
  type        = bool
  default     = false
  description = "Whether to create the k8s namespace"
}

variable "create_docker_registry_secret" {
  type        = bool
  default     = false
  description = "Whether to create the docker registry secret. A worker node in the Kubernetes cluster needs to authenticate against the docker registry"
}

variable "docker_registry_secret_name" {
  type        = string
  default     = "docker-registry-cred"
  description = "Secret name to store docker registry credentials"
}

variable "docker_registry_server" {
  type        = string
  default     = "my.example.com"
  description = "The domain name for the docker-registry server"
}

variable "docker_user" {
  type        = string
  default     = "registry-user"
  description = "The username for the docker-registry server"
}

variable "docker_password" {
  type        = string
  default     = "password"
  description = "The password for the docker-registry server"
}

variable "docker_email" {
  type        = string
  default     = "info@example.com"
  description = "The email for the docker-registry server"
}

variable "create_tiller" {
  type        = bool
  default     = false
  description = "Whether to create the k8s Tiller for deploy applications via Helm"
}

variable "tiller_image" {
  type        = string
  default     = "docker.example.com/tiller:v2.15.0"
  description = "Docker images for Tiller deploy"
}

variable "create_metric_server" {
  type        = bool
  default     = false
  description = "Whether to create the k8s metric-server for basic metrics from deployed applications into EKS"
}

variable "metric_server_version" {
  type        = string
  default     = "v0.3.5"
  description = "Metric server version"
}

variable "metric_image" {
  type        = string
  default     = "docker.example.com/metrics-server-amd64"
  description = "Docker images for metric-server deploy"
}

variable "create_cluster_autoscaler" {
  type        = bool
  default     = true
  description = "Whether to create the k8s cluster-autoscaler"
}

variable "cluster_autoscaler_version" {
  type        = string
  default     = "v1.12.3"
  description = "Cluster Autoscaler version"
}

variable "cluster_autoscaler_image" {
  type        = string
  default     = "docker.example.com/cluster-autoscaler"
  description = "Docker images for cluster-autoscaler deploy"
}

variable "create_nginx_ingress_controller" {
  type        = bool
  default     = false
  description = "Whether to create the nginx ingress controller"
}

variable "nginx_ingress_controller_image" {
  type        = string
  default     = "docker.example.com/nginx-ingress-controller"
  description = "Docker images for nginx-ingress-controller"
}

variable "nginx_ingress_controller_version" {
  type        = string
  default     = "0.26.1"
  description = "Nginx ingress controller version"
}

variable "allowed_cidr_block" {
  type        = list(string)
  default     = ["0.0.0.0/0"]
  description = "Allowed cidr blocks to communicate with the EKS cluster API"
}

# Node groups

## Node group role

variable "eks_node_group_role_name" {
  type = string
  description = "Name for the role for the EKS Node group"
}

variable "eks_node_group_role_policy_document_json" {
  type = string
  description = "IAM Role permission policy for the EKS Node group"
}

variable "eks_node_group_asg_policy_name" {
  type = string
  description = "Name of IAM policy for ASG permissions for EKS Node Group"
}

variable "eks_external_dns_policy_name" {
  type = string
  description = "Name of ExternalDNS IAM policy"
  default = null
}

variable "node_groups" {
  type = list(object({
    instance_type                 = optional(string),
    ami_id                        = optional(string),
    key_name                      = optional(string),
    ebs_optimized                 = optional(string),
    additional_security_group_ids = optional(list(string)),
    public_ip                     = optional(string),
    enable_monitoring             = optional(string),
    placement_tenancy             = optional(string),
    root_volume_size              = optional(string),
    root_volume_type              = optional(string),
    root_iops                     = optional(string),
    name                          = string,
    desired_size                  = number
    max_size                      = number
    min_size                      = number
  }))
  default     = []
  description = "List of Node Groups with parameters"
}

variable "node_group_launch_template_defaults" {
  type        = map(string)
  default     = {}
  description = "Override default values for node groups. See workers_group_defaults_defaults in locals.tf for valid keys."
}

variable "node_create_security_group" {
  description = "Whether to create a security group for the nodes or attach the nodes to `node_security_group_id`."
  default     = true
}

variable "node_sg_ingress_from_port" {
  type        = number
  default     = 1025
  description = "Minimum port number from which pods will accept communication. Must be changed to a lower value if some pods in your cluster will expose a port lower than 1025 (e.g. 22, 80, or 443)."
}

variable "node_security_group_id" {
  type        = string
  default     = ""
  description = "If provided, all workers will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the EKS cluster."
}

variable "node_additional_security_group_ids" {
  type        = list(string)
  default     = []
  description = "A list of additional security group ids to attach to worker instances"
}

variable "helm_assume_role_arn_list" {
  type        = list(string)
  default     = []
  description = "A list of assume role arns used by helm to connect to EKS clusters"
}

variable "ebs_csi_driver_addon_enabled" {
  type        = bool
  default     = false
  description = "Whether to install EBS CSI driver add-on or not"
}

variable "ebs_csi_driver_addon_version" {
  type        = string
  default     = "v1.13.0-eksbuild.3"
  description = "Amazon EBS CSI driver add-on version"
}

variable "eks_security_group_ingress_rules" {
  type = map(object({
    description : string
    protocol : string
    port : number
    cidr_blocks: list(string)
  }))
  default     = {}
  description = "Extra ingress rules to apply to the EKS nodes"
}
