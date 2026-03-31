# =============================================================
# main.tf — точка входа Terraform
#
# Что происходит здесь:
#   1. Подключаем провайдер VirtualBox (virtualbox-ng)
#   2. Три раза вызываем модуль vm/ — создаём три ВМ
#      с разными именами и ролями
#
# Запуск:
#   terraform init    ← скачать провайдер
#   terraform plan    ← показать план изменений
#   terraform apply   ← создать ВМ
#   terraform destroy ← удалить ВМ
# =============================================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    # virtualbox-ng — активно поддерживаемый форк провайдера VirtualBox
    # Docs: https://registry.terraform.io/providers/terra-farm/virtualbox
    virtualbox = {
      #source  = "terra-farm/virtualbox"
      #version = "0.2.2-alpha.1"
      #source  = "terra-farm/virtualbox"
      source  = "shekeriev/virtualbox"      
      version = "0.0.4"
      #version = "~> 0.2.1-"
    }
  }

  # В production стейт нужно хранить удалённо (S3/MinIO/GitLab).
  # Для локальной разработки достаточно локального файла terraform.tfstate.
  # backend "s3" {
  #   bucket = "devops-tfstate"
  #   key    = "devtracker/terraform.tfstate"
  #   region = "us-east-1"
  # }
}

provider "virtualbox" {
  # Провайдер использует VirtualBox CLI (VBoxManage), который должен
  # быть установлен на хост-машине. Дополнительных настроек не требует.
}

# =============================================================
# ЛОКАЛЬНЫЕ ПЕРЕМЕННЫЕ
# Используем local.nodes — карту нод кластера.
# Это позволяет добавить новую ноду, просто добавив строку в map.
# =============================================================
locals {
  nodes = {
    "control-plane" = {
      cpus    = var.control_plane_cpus
      memory  = var.control_plane_memory_mb
      ip      = var.control_plane_ip
      role    = "control-plane"
    }
    "worker-01" = {
      cpus    = var.worker_cpus
      memory  = var.worker_memory_mb
      ip      = var.worker_ips[0]
      role    = "worker"
    }
    "worker-02" = {
      cpus    = var.worker_cpus
      memory  = var.worker_memory_mb
      ip      = var.worker_ips[1]
      role    = "worker"
    }
  }
}

# =============================================================
# СОЗДАНИЕ ВМ
# for_each итерирует по карте nodes и создаёт модуль для каждой.
# =============================================================
module "k8s_nodes" {
  source   = "./modules/vm"
  for_each = local.nodes

  # Имя ВМ в VirtualBox
  vm_name  = "${var.cluster_name}-${each.key}"

  # Вычислительные ресурсы
  cpus     = each.value.cpus
  memory   = each.value.memory

  # Сеть
  ip_address  = each.value.ip
  subnet_mask = var.subnet_mask
  gateway     = var.gateway

  # Образ диска (vagrant box, конвертированный в .ova)
  image_path = var.base_image_path

  # SSH ключ для подключения Ansible
  ssh_public_key = var.ssh_public_key

  # Теги для идентификации
  role         = each.value.role
  cluster_name = var.cluster_name
}
