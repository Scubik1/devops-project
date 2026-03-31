# =============================================================
# outputs.tf — вывод информации после terraform apply
#
# После успешного apply Terraform напечатает IP-адреса нод.
# Эти значения используются двумя способами:
#   1. Вручную — для проверки и подключения по SSH
#   2. Автоматически — Ansible может читать output через:
#      terraform output -json > /tmp/tf_output.json
# =============================================================

output "control_plane_ip" {
  description = "IP-адрес control-plane ноды. Используется для kubeadm init и kubectl."
  value       = module.k8s_nodes["control-plane"].ip_address
}

output "worker_ips" {
  description = "IP-адреса worker-нод. Используются для kubeadm join."
  value = {
    "worker-01" = module.k8s_nodes["worker-01"].ip_address
    "worker-02" = module.k8s_nodes["worker-02"].ip_address
  }
}

output "all_node_ips" {
  description = "Все IP-адреса кластера в виде списка. Удобно для Ansible inventory."
  value       = [
    for name, node in module.k8s_nodes : {
      name = name
      ip   = node.ip_address
      role = node.role
    }
  ]
}

output "ssh_connect_commands" {
  description = "Готовые команды для подключения по SSH к каждой ноде."
  value = {
    for name, node in module.k8s_nodes :
    name => "ssh -i ~/.ssh/k8s_rsa ubuntu@${node.ip_address}"
  }
}

output "cluster_summary" {
  description = "Сводная информация о кластере."
  value = <<EOF

╔══════════════════════════════════════════════╗
║         K8s Cluster Infrastructure           ║
╠══════════════════════════════════════════════╣
║  control-plane : ${module.k8s_nodes["control-plane"].ip_address}              ║
║  worker-01     : ${module.k8s_nodes["worker-01"].ip_address}              ║
║  worker-02     : ${module.k8s_nodes["worker-02"].ip_address}              ║
╠══════════════════════════════════════════════╣
║  Следующий шаг: запустить Ansible            ║
║  cd ../ansible && ansible-playbook site.yml  ║
╚══════════════════════════════════════════════╝
EOF
}
