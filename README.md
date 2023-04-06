# AWS EKS Terraform module

Author: [Yurii Onuk](https://onuk.org.ua)

Terraform module which creates [EKS cluster](https://aws.amazon.com/eks/)

Next types of resources are supported:

* [Template file](https://www.terraform.io/docs/providers/template/d/file.html)
* [Local file](https://www.terraform.io/docs/providers/local/r/file.html)
* [Null Resource](https://www.terraform.io/docs/providers/null/resource.html)
* [AWS iam policy document](https://www.terraform.io/docs/providers/aws/d/iam_policy_document.html)
* [AWS ami](https://www.terraform.io/docs/providers/aws/d/ami.html)
* [AWS eks cluster](https://www.terraform.io/docs/providers/aws/r/eks_cluster.html)
* [AWS security group](https://www.terraform.io/docs/providers/aws/r/security_group.html)
* [AWS security group rule](https://www.terraform.io/docs/providers/aws/r/security_group_rule.html)
* [AWS iam role](https://www.terraform.io/docs/providers/aws/r/iam_role.html)
* [AWS iam role policy attachment](https://www.terraform.io/docs/providers/aws/r/iam_role_policy_attachment.html)
* [AWS autoscaling group](https://www.terraform.io/docs/providers/aws/r/autoscaling_group.html)
* [AWS launch configuration](https://www.terraform.io/docs/providers/aws/r/launch_configuration.html)
* [AWS iam instance profile](https://www.terraform.io/docs/providers/aws/r/iam_instance_profile.html)
* [AWS iam policy](https://www.terraform.io/docs/providers/aws/r/iam_policy.html)
* [AWS launch template](https://www.terraform.io/docs/providers/aws/r/launch_template.html)
* [AWS EKS Addon](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/eks_addon)

## Terraform version compatibility

- 0.12.29
- 1.1.5

## Prerequisites

* [Aws iam authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html)
* [Kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* [aws-mfa](https://github.com/broamski/aws-mfa)
* [helm](https://github.com/helm/helm/releases)

### Required versions

| Tools                 | Client Version | Server Version       |
|-----------------------|----------------|----------------------|
| kubectl               | v1.26.1        | v1.24.10-eks-48e63af |
| helm                  | v3.10.3        | v3.10.3              |
| aws-iam-authenticator | 1.11.8         | -                    |
| aws-mfa               | latest         | -                    |

## Usage

main.tf:

```hcl-terraform
################
# AWS Provider #
################
provider "aws" {
  region = var.region
}

########################
# Configure S3 backend #
########################
terraform {
  backend "s3" {
    workspace_key_prefix = ""
    required_version     = "= 0.12.10"
  }
}

##############################################################
# COMMON composed VALUES shared across the different modules #
##############################################################
locals {
  app_environment_triplet = terraform.workspace
  common_tags = {
    EnvClass    = var.env_class
    Environment = var.env_name
    Owner       = var.env_owner
    Terraform   = "true"
  }
  # Name of EKS CLUSTER
  cluster_name = "${var.env_name}-${var.env_class}-eks-cluster"

  # Local VARS for EKS ( LaunchConfigurations and LaunchTemplates )
  worker_groups = [
    {
      ######################################################################
      # This will launch an autoscaling group with only On-Demand instances
      ######################################################################
      instance_type         = var.eks_instance_type
      additional_userdata   = "echo foo bar"
      subnets               = join(",", module.vpc.private_subnet_id_list)
      asg_desired_capacity  = var.asg_desired_capacity
      asg_max_size          = var.asg_max_size
      asg_min_size          = var.asg_min_size
      autoscaling_enabled   = var.autoscaling_enabled
      protect_from_scale_in = var.protect_from_scale_in
    },
  ]
  worker_groups_launch_template = [
    {
      ######################################################################
      # This will launch an autoscaling group with only On-Demand instances
      ######################################################################
      instance_type         = var.eks_instance_type
      additional_userdata   = "echo foo bar"
      subnets               = join(",", module.vpc.private_subnet_id_list)
      asg_desired_capacity  = var.asg_desired_capacity
      asg_max_size          = var.asg_max_size
      asg_min_size          = var.asg_min_size
      autoscaling_enabled   = var.autoscaling_enabled
      protect_from_scale_in = var.protect_from_scale_in
    },
  ]
}

########################
# Creating EKS CLUSTER #
########################

module "eks" {
  source                 = "git@github.com:equinor/flowify-terraform-aws-eks.git?ref=v.0.0.1"
  region                 = var.region
  env_name               = var.env_name
  env_owner              = var.env_owner
  env_class              = var.env_class
  cluster_name           = local.cluster_name
  common_tags            = local.common_tags
  subnets                = module.vpc.private_subnet_id_list
  vpc_id                 = module.vpc.vpc_id
  custom_ami             = var.custom_ami_enabled
  ami_custom_name        = var.ami_custom_name
  ami_custom_owner       = var.ami_custom_owner
  cluster_version        = var.cluster_version
  config_output_path     = var.config_output_path
  cluster_public_access  = var.cluster_public_access
  cluster_private_access = var.cluster_private_access
  allowed_cidr_block     = [module.vpc.vpc_cidr_block]

  kubeconfig_aws_authenticator_env_variables = {
    AWS_PROFILE = var.env_class
  }

  worker_groups                      = local.worker_groups
  worker_groups_launch_template      = local.worker_groups_launch_template
  worker_group_count                 = var.worker_group_count
  worker_group_launch_template_count = var.worker_group_launch_template_count

  # Enabling/Disabling object creation inside a EKS cluster
  create_ns                       = true
  create_tiller                   = true
  create_metric_server            = true
  create_cluster_autoscaler       = true
  create_nginx_ingress_controller = true
}
```

outputs.tf:

```hcl-terraform
output "cluster_name" {
  value = "${module.eks.cluster_id}"
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane."
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ids attached to the cluster control plane."
  value       = module.eks.cluster_security_group_id
}

output "worker_security_group_id" {
  value       = module.eks.worker_security_group_id
}

output "identity_oidc" {
  description = "Nested attribute containing identity provider information for your cluster."
  value       = module.eks.identity_oidc
}

output "openid_connect_provider" {
  description = "The ARN assigned by AWS for this provider."
  value       = module.eks.openid_connect_provider
}
```

variable.tf:

```hcl-terraform
#########################
# Common variable block #
#########################

variable "region" {
  type        = string
  description = "The region where AWS operations will take place"
}

variable "env_class" {
  type        = "string"
  description = "The environment class tag that will be added to all taggable resources"
}

variable "env_name" {
  type        = "string"
  description = "The description that will be applied to the tags for resources created in the vpc configuration"
}

variable "env_owner" {
  type        = "string"
  description = "The environment owner tag that will be added to all taggable resources"
}

#######
# EKS #
#######

variable "asg_desired_capacity" {
  type        = "string"
  description = "Desired worker capacity in the autoscaling group"
  default     = "3"
}

variable "asg_min_size" {
  type        = "string"
  description = "Minimum worker capacity in the autoscaling group"
  default     = "2"
}

variable "asg_max_size" {
  type        = "string"
  description = "Maximum worker capacity in the autoscaling group"
  default     = "10"
}

variable "autoscaling_enabled" {
  description = "Autoscaling of worker nodes"
  default     = true
}

variable "protect_from_scale_in" {
  description = "to ensure that cluster-autoscaler is solely responsible for scaling events"
  default     = false
}

variable "worker_group_count" {
  default = "1"
}

variable "worker_group_launch_template_count" {
  default = "0"
}

variable "eks_instance_type" {
  type        = "string"
  default     = "m4.xlarge"
  description = "Instance type for EKS Cluster Worker Nodes"
}

variable "custom_ami_enabled" {
  type        = "string"
  default     = "false"
  description = "Whether to create EKS cluster from custom AMI name"
}

variable "ami_custom_name" {
  type        = "string"
  default     = "eks-node-us-east-1-CentOS-7-*"
  description = "Custom AMI name"
}

variable "ami_custom_owner" {
  type        = "string"
  default     = "195572076609"
  description = "Owner ID for custom AMI"
}

variable "cluster_version" {
  type        = "string"
  default     = "1.24"
  description = "Kubernetes version to use for the EKS cluster"
}

variable "config_output_path" {
  type        = string
  default     = "./eks_services_configs/"
  description = "Where to save the Kubectl config file (if `write_kubeconfig = true`). Should end in a forward slash `/` ."
}

variable "cluster_public_access" {
  type        = bool
  default     = false
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled."
}

variable "cluster_private_access" {
  type        = bool
  default     = true
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled."
}
```

terraform.tfvars:

```hcl-terraform
#########################
# Backend configuration #
#########################

# AWS Regions
region = "us-east-2"

# Add environment owner to tags
env_owner = "DevOps"
```

## Inputs

| Variable                                       |      Type      | Default                                         | Required | Purpose                                                                                                                                                                                                                                      |
|:-----------------------------------------------|:--------------:|-------------------------------------------------|----------|:---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `region`                                       |    `string`    | `us-west-2`                                     | `no`     | `The region where AWS operations will take place`                                                                                                                                                                                            |
| `env_name`                                     |    `string`    | `usw201`                                        | `no`     | `Environment name to be used on all the resources as identifier`                                                                                                                                                                             |
| `env_class`                                    |    `string`    | `dev`                                           | `no`     | `The environment class tag that will be added to all taggable resources`                                                                                                                                                                     |
| `env_owner`                                    |    `string`    | `DevOps`                                        | `no`     | `The environment owner tag that will be added to all taggable resources`                                                                                                                                                                     |
| `cluster_name`                                 |    `string`    | `cluster-name`                                  | `no`     | `Name of the EKS cluster. Also used as a prefix in names of related resources`                                                                                                                                                               |
| `cluster_security_group_id`                    |    `string`    | `""`                                            | `no`     | `If provided, the EKS cluster will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the workers and provide API access to your current IP/32`                    |
| `cluster_version`                              |    `string`    | `1.24`                                          | `no`     | `Kubernetes version to use for the EKS cluster`                                                                                                                                                                                              |
| `config_output_path`                           |    `string`    | `./`                                            | `no`     | `Where to save the Kubectl config file (if write_kubeconfig = true). Should end in a forward slash /`                                                                                                                                        |
| `write_kubeconfig`                             |     `bool`     | `true`                                          | `no`     | `Whether to write a Kubectl config file containing the cluster configuration. Saved to config_output_path`                                                                                                                                   |
| `manage_aws_auth`                              |     `bool`     | `true`                                          | `no`     | `Whether to write and apply the aws-auth configmap file`                                                                                                                                                                                     |
| `map_accounts`                                 |     `list`     | `[]`                                            | `no`     | `Additional AWS account numbers to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format`                                                                                                             |
| `map_accounts_count`                           |    `string`    | `0`                                             | `no`     | `The count of accounts in the map_accounts list`                                                                                                                                                                                             |
| `map_roles`                                    |     `list`     | `[]`                                            | `no`     | `Additional IAM roles to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format`                                                                                                                       |
| `map_roles_count`                              |    `string`    | `0`                                             | `no`     | `The count of roles in the map_roles list`                                                                                                                                                                                                   |
| `map_users`                                    |     `list`     | `[]`                                            | `no`     | `Additional IAM users to add to the aws-auth configmap. See examples/eks_test_fixture/variables.tf for example format`                                                                                                                       |
| `map_users_count`                              |    `string`    | `0`                                             | `no`     | `The count of roles in the map_users list`                                                                                                                                                                                                   |
| `subnets`                                      |     `list`     | `no`                                            | `yes`    | `A list of subnets to place the EKS cluster and workers within`                                                                                                                                                                              |
| `vpc_id`                                       |    `string`    | `no`                                            | `yes`    | `VPC where the cluster and workers will be deployed`                                                                                                                                                                                         |
| `worker_groups`                                |     `list`     | `yes`                                           | `no`     | `A list of maps defining worker group configurations to be defined using AWS Launch Configurations. See workers_group_defaults for valid keys`                                                                                               |
| `worker_group_count`                           |    `string`    | `1`                                             | `no`     | `The number of maps contained within the worker_groups list`                                                                                                                                                                                 |
| `workers_group_defaults`                       |     `map`      | `{}`                                            | `no`     | `Override default values for target groups. See workers_group_defaults_defaults in locals.tf for valid keys`                                                                                                                                 |
| `worker_groups_launch_template`                |     `list`     | `yes`                                           | `no`     | `A list of maps defining worker group configurations to be defined using AWS Launch Templates. See workers_group_defaults for valid keys`                                                                                                    |
| `worker_group_launch_template_count`           |    `string`    | `0`                                             | `no`     | `The number of maps contained within the worker_groups_launch_template list`                                                                                                                                                                 |
| `workers_group_launch_template_defaults`       |     `map`      | `{}`                                            | `no`     | `Override default values for target groups. See workers_group_defaults_defaults in locals.tf for valid keys`                                                                                                                                 |
| `worker_security_group_id`                     |    `string`    | `""`                                            | `no`     | `If provided, all workers will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the EKS cluster`                                                                 |
| `worker_additional_security_group_ids`         |     `list`     | `[]`                                            | `no`     | `A list of additional security group ids to attach to worker instances`                                                                                                                                                                      |
| `worker_sg_ingress_from_port`                  |    `string`    | `1025`                                          | `no`     | `Minimum port number from which pods will accept communication. Must be changed to a lower value if some pods in your cluster will expose a port lower than 1025 (e.g. 22, 80, or 443)`                                                      |
| `kubeconfig_aws_authenticator_command`         |    `string`    | `aws-iam-authenticator`                         | `no`     | `Command to use to fetch AWS EKS credentials`                                                                                                                                                                                                |
| `kubeconfig_aws_authenticator_command_args`    |     `list`     | `[]`                                            | `no`     | `Default arguments passed to the authenticator command. Defaults to [token -i $cluster_name]`                                                                                                                                                |
| `kubeconfig_aws_authenticator_additional_args` |     `list`     | `[]`                                            | `no`     | `Any additional arguments to pass to the authenticator such as the role to assume. e.g. ["-r", "MyEksRole"]`                                                                                                                                 |
| `kubeconfig_aws_authenticator_env_variables`   |     `map`      | `{}`                                            | `no`     | `Environment variables that should be used when executing the authenticator. e.g. { AWS_PROFILE = "eks"}`                                                                                                                                    |
| `kubeconfig_name`                              |    `string`    | `""`                                            | `no`     | `Override the default name used for items kubeconfig`                                                                                                                                                                                        |
| `cluster_create_timeout`                       |    `string`    | `15m`                                           | `no`     | `Timeout value when creating the EKS cluster`                                                                                                                                                                                                |
| `cluster_delete_timeout`                       |    `string`    | `15m`                                           | `no`     | `Timeout value when deleting the EKS cluster`                                                                                                                                                                                                |
| `local_exec_interpreter`                       |     `list`     | `["/bin/sh", "-c"]`                             | `no`     | `Command to run for local-exec resources. Must be a shell-style interpreter. If you are on Windows Git Bash is a good choice`                                                                                                                |
| `cluster_create_security_group`                |     `bool`     | `true`                                          | `no`     | `Whether to create a security group for the cluster or attach the cluster to cluster_security_group_id`                                                                                                                                      |
| `worker_create_security_group`                 |     `bool`     | `true`                                          | `no`     | `Whether to create a security group for the workers or attach the workers to worker_security_group_id`                                                                                                                                       |
| `worker_ami_name_filter`                       |    `string`    | `v*`                                            | `no`     | `Additional name filter for AWS EKS worker AMI. Default behaviour will get latest for the cluster_version but could be set to a release from amazon-eks-ami, e.g. \"v20190220\"`                                                             |
| `ami_name_eks`                                 |    `string`    | `amazon-eks-node`                               | `no`     | `Amazon EKS node AMI name`                                                                                                                                                                                                                   |
| `ami_custom_name`                              |    `string`    | `"amazon-eks-node-1.24-*"`                      | `no`     | `Custom AMI name`                                                                                                                                                                                                                            |
| `custom_ami`                                   |    `string`    | `false`                                         | `no`     | `Whether to create EKS cluster from custom AMI name`                                                                                                                                                                                         |
| `ami_custom_owner`                             |    `string`    | `"1955720xxxxx"`                                | `no`     | `Owner ID for custom AMI`                                                                                                                                                                                                                    |
| `ami_owner`                                    |    `string`    | `"6024011xxxxx"`                                | `no`     | `Owner ID for Amazon EKS node AMI`                                                                                                                                                                                                           |
| `enabled_cluster_log_types`                    |     `list`     | `[]`                                            | `no`     | `A list of the desired control plane logging to enable. For more information, see https://docs.aws.amazon.com/en_us/eks/latest/userguide/control-plane-logs.html. Possible values [api, audit, authenticator, controllerManager, scheduler]` |
| `cluster_private_access`                       |     `bool`     | `false`                                         | `no`     | `Indicates whether or not the Amazon EKS private API server endpoint is enabled`                                                                                                                                                             |
| `cluster_public_access`                        |     `bool`     | `true`                                          | `no`     | `Indicates whether or not the Amazon EKS public API server endpoint is enabled`                                                                                                                                                              |
| `create_ns`                                    |     `bool`     | `true`                                          | `no`     | `Whether to create the k8s namespace`                                                                                                                                                                                                        |
| `create_docker_registry_secret`                |     `bool`     | `true`                                          | `no`     | `Whether to create the docker registry secret. A worker node in the Kubernetes cluster needs to authenticate against the docker registry`                                                                                                    |
| `docker_registry_secret_name`                  |    `string`    | `docker-registry-cred`                          | `no`     | `Secret name to store docker registry credentials`                                                                                                                                                                                           |
| `docker_registry_server`                       |    `string`    | `docker.example.com`                            | `no`     | `The domain name for the docker-registry server`                                                                                                                                                                                             |
| `docker_user`                                  |    `string`    | `docker-registry-user`                          | `no`     | `The username for the docker-registry server`                                                                                                                                                                                                |
| `docker_password`                              |    `string`    | `xxxxxxxxxxxxxxx`                               | `no`     | `The password for the docker-registry server`                                                                                                                                                                                                |
| `docker_email`                                 |    `string`    | `system@example.com`                            | `no`     | `The email for the docker-registry server`                                                                                                                                                                                                   |
| `create_tiller`                                |     `bool`     | `true`                                          | `no`     | `Whether to create the k8s Tiller for deploy applications via Helm`                                                                                                                                                                          |
| `tiller_image`                                 |    `string`    | `docker.example.com/tiller:v2.15.0`             | `no`     | `Docker images for Tiller deploy`                                                                                                                                                                                                            |
| `create_metric_server`                         |     `bool`     | `true`                                          | `no`     | `Whether to create the k8s metric-server for basic metrics from deployed applications into EKS`                                                                                                                                              |
| `metric_server_version`                        |    `string`    | `v0.3.5`                                        | `no`     | `Metric server version`                                                                                                                                                                                                                      |
| `metric_image`                                 |    `string`    | `docker.example.com/metrics-server-amd64`       | `no`     | `Docker images for metric-server deploy`                                                                                                                                                                                                     |
| `create_cluster_autoscaler`                    |     `bool`     | `true`                                          | `no`     | `Whether to create the k8s cluster-autoscaler`                                                                                                                                                                                               |
| `cluster_autoscaler_version`                   |    `string`    | `v1.24.0`                                       | `no`     | `Cluster Autoscaler version`                                                                                                                                                                                                                 |
| `cluster_autoscaler_image`                     |    `string`    | `docker.example.com/cluster-autoscaler`         | `no`     | `Docker images for cluster-autoscaler deploy`                                                                                                                                                                                                |
| `create_nginx_ingress_controller`              |     `bool`     | `true`                                          | `no`     | `Whether to create the nginx ingress controller`                                                                                                                                                                                             |
| `nginx_ingress_controller_image`               |    `string`    | `docker.example.com/nginx-ingress-controller`   | `no`     | `Docker images for nginx-ingress-controller`                                                                                                                                                                                                 |
| `nginx_ingress_controller_version`             |    `string`    | `0.26.1`                                        | `no`     | `Nginx ingress controller version`                                                                                                                                                                                                           |
| `allowed_cidr_block`                           | `list(string)` | `["0.0.0.0/0"]`                                 | `no`     | `Allowed cidr blocks to communicate with the EKS cluster API`                                                                                                                                                                                |
| `helm_assume_role_arn_list`                    | `list(string)` | `[]`                                            | `no`     | `A list of assume role arns used by helm to connect to EKS clusters`                                                                                                                                                                         |
| `eks_node_group_role_name`                     |    `string`    | -                                               | `yes`    | `Name for the role for the EKS Node group`                                                                                                                                                                                                   |
| `eks_node_group_role_policy_document_json`     |    `string`    | -                                               | `yes`    | `"IAM Role permission policy for the EKS Node group`                                                                                                                                                                                         |
| `eks_node_group_asg_policy_name`               |    `string`    | -                                               | `yes`    | `Name of IAM policy for ASG permissions for EKS Node Group`                                                                                                                                                                                  |
| `node_groups`                                  | `list(object)` | `[]`                                            | `yes`    | `List of Node Groups with parameters`                                                                                                                                                                                                        |
| `node_group_launch_template_defaults`          | `map(string)`  | `{}`                                            | `yes`    | `Override default values for node groups. See workers_group_defaults_defaults in locals.tf for valid keys.`                                                                                                                                  |
| `node_create_security_group`                   |       -        | -                                               | `yes`    | `Whether to create a security group for the nodes or attach the nodes to node_security_group_id`                                                                                                                                             |
| `node_sg_ingress_from_port`                    |    `number`    | `1025`                                          | `yes`    | `Minimum port number from which pods will accept communication. Must be changed to a lower value if some pods in your cluster will expose a port lower than 1025 (e.g. 22, 80, or 443).`                                                     |
| `node_security_group_id`                       |    `string`    | `""`                                            | `yes`    | `If provided, all workers will be attached to this security group. If not given, a security group will be created with necessary ingres/egress to work with the EKS cluster.`                                                                |
| `node_additional_security_group_ids`           | `list(string)` | `[]`                                            | `yes`    | `A list of additional security group ids to attach to worker instances`                                                                                                                                                                      |
| `eks_external_dns_policy_name`                 |    `string`    | `null`                                          | `no`     | `Name of ExternalDNS IAM policy`                                                                                                                                                                                                             |
| `ebs_csi_driver_addon_enabled`                 |     `bool`     | `true`                                          | `no`     | `Whether to install EBS CSI driver add-on or not`                                                                                                                                                                                            |
| `ebs_csi_driver_addon_version`                 |    `string`    | `v1.13.0-eksbuild.3`                            | `no`     | `Amazon EBS CSI driver add-on version`                                                                                                                                                                                                       |

## Outputs

| Name                                 | Description                                                                                                                                                      |
|--------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `cluster_id`                         | `The name/id of the EKS cluster`                                                                                                                                 |
| `cluster_arn`                        | `The Amazon Resource Name (ARN) of the cluster`                                                                                                                  |
| `cluster_certificate_authority_data` | `Nested attribute containing certificate-authority-data for your cluster. This is the base64 encoded certificate data required to communicate with your cluster` |
| `cluster_endpoint`                   | `The endpoint for your EKS Kubernetes API`                                                                                                                       |
| `cluster_version`                    | `The Kubernetes server version for the EKS cluster`                                                                                                              |
| `cluster_security_group_id`          | `Security group ID attached to the EKS cluster`                                                                                                                  |
| `config_map_aws_auth`                | `A kubernetes configuration to authenticate to this EKS cluster`                                                                                                 |
| `kubeconfig`                         | `kubectl config file contents for this EKS cluster`                                                                                                              |
| `workers_asg_arns`                   | `IDs of the autoscaling groups containing workers`                                                                                                               |
| `workers_asg_names`                  | `Names of the autoscaling groups containing workers`                                                                                                             |
| `worker_security_group_id`           | `Security group ID attached to the EKS workers`                                                                                                                  |
| `worker_iam_role_name`               | `default IAM role name for EKS worker groups`                                                                                                                    |
| `worker_iam_role_arn`                | `default IAM role ARN for EKS worker groups`                                                                                                                     |
| `identity_oidc`                      | `Nested attribute containing identity provider information for your cluster`                                                                                     |
| `openid_connect_provider`            | `The ARN assigned by AWS for this provider`                                                                                                                      |

## Terraform Validate Action

Runs `terraform validate -var-file=validator` to validate the Terraform files 
in a module directory via CI/CD pipeline.
Validation includes a basic check of syntax as well as checking that all variables declared.

### Success Criteria

This action succeeds if `terraform validate -var-file=validator` runs without error.

### Validator

If some variables are not set as default, we should fill the file `validator` with these variables.
