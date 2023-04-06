######################
# Generate kubeconfig
######################

resource "local_file" "kubeconfig" {
  content  = local.template_kubeconfig
  filename = "${var.config_output_path}kubeconfig"
  count    = var.write_kubeconfig ? 1 : 0
}
