# =============================================================
# modules/vm/main.tf — описание одной виртуальной машины
#
# Этот модуль использует провайдер terra-farm/virtualbox.
# Провайдер под капотом вызывает VBoxManage CLI.
#
# Сетевая конфигурация:
#   - Адаптер 1 (NAT)       — доступ в интернет для скачивания пакетов
#   - Адаптер 2 (Host-Only) — статический IP для связи между нодами
#                             и подключения с хост-машины
#
# Cloud-init:
#   user_data передаёт начальную конфигурацию в ВМ при первом старте:
#   - создаёт пользователя ubuntu
#   - прописывает SSH-ключ
#   - устанавливает hostname
# =============================================================

terraform {
  required_providers {
    virtualbox = {
      #source  = "terra-farm/virtualbox"
      #version = "0.2.2-alpha.1"
      source  = "shekeriev/virtualbox"      
      version = "0.0.4"
      #source  = "terra-farm/virtualbox"
      #version = "0.2.1"
      #version = "~> 0.2.1-"
    }
  }
}

# Главный ресурс — виртуальная машина VirtualBox
resource "virtualbox_vm" "node" {
  name   = var.vm_name
  image  = var.image_path

  # Вычислительные ресурсы
  cpus   = var.cpus
  memory = "${var.memory} mib"

  # --------------- Сетевые адаптеры -------------------------
  network_adapter {
    # Адаптер 1: NAT — ВМ получает доступ в интернет через хост
    # IP назначается автоматически (обычно 10.0.2.x)
    type           = "nat"
    host_interface = "eth0"
  }

  network_adapter {
    # Адаптер 2: Host-Only — статический IP для внутренней сети K8s
    # В VirtualBox должна быть создана сеть vboxnet0 (192.168.56.0/24)
    # Создать командой: VBoxManage hostonlyif create
    type           = "hostonly"
    host_interface = "vboxnet0"
  }

  # --------------- Cloud-init / user_data -------------------
  # user_data передаётся как ISO-образ NoCloud.
  # Провайдер virtualbox-ng поддерживает это поле начиная с v0.2.
  user_data = templatefile("${path.module}/cloud-init.tpl", {
    hostname       = var.vm_name
    ip_address     = var.ip_address
    subnet_mask    = var.subnet_mask
    gateway        = var.gateway
    ssh_public_key = var.ssh_public_key
  })
}

# --------------- Outputs модуля --------------------------------
output "ip_address" {
  description = "IP-адрес ВМ в host-only сети."
  value       = var.ip_address
}

output "role" {
  description = "Роль ноды."
  value       = var.role
}

output "vm_name" {
  description = "Имя ВМ в VirtualBox."
  value       = virtualbox_vm.node.name
}
