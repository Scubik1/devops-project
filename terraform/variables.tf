# =============================================================
# variables.tf — все настраиваемые параметры кластера
#
# Принцип: значения по умолчанию заданы для локальной разработки.
# Для другого окружения создайте файл terraform.tfvars или
# передайте переменные через -var "name=value".
#
# Пример terraform.tfvars (НЕ коммитить в git если содержит секреты):
#   base_image_path = "/home/user/ubuntu-22.04.ova"
#   ssh_public_key  = "ssh-rsa AAAA..."
# =============================================================

# ------- Общие настройки кластера ----------------------------

variable "cluster_name" {
  description = "Префикс для имён ВМ в VirtualBox. Итоговые имена: <cluster_name>-control-plane, <cluster_name>-worker-01 и т.д."
  type        = string
  default     = "k8s"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,20}$", var.cluster_name))
    error_message = "cluster_name должен состоять из строчных букв, цифр и дефисов (2–20 символов)."
  }
}

variable "base_image_path" {
  description = <<EOF
Путь к базовому образу диска Ubuntu 22.04 в формате .ova или .vmdk.
Образ должен быть предварительно скачан:
  vagrant box add bento/ubuntu-22.04 --provider=virtualbox
  # Путь к box: ~/.vagrant.d/boxes/bento-VAGRANTSLASH-ubuntu-22.04/...
EOF
  type        = string
  default     = "ubuntu-22.04-amd64.ova"
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ для добавления в ~/.ssh/authorized_keys на ВМ. Ansible будет подключаться по соответствующему приватному ключу."
  type        = string
  # В CI/CD передавать через переменную окружения: TF_VAR_ssh_public_key
}

# ------- Ресурсы control-plane --------------------------------

variable "control_plane_cpus" {
  description = "Количество vCPU для control-plane ноды. Минимум по ТЗ: 2."
  type        = number
  default     = 2

  validation {
    condition     = var.control_plane_cpus >= 2
    error_message = "Control-plane требует минимум 2 vCPU (требование kubeadm)."
  }
}

variable "control_plane_memory_mb" {
  description = "Оперативная память control-plane в МБ. Минимум по ТЗ: 4096 (4 GB)."
  type        = number
  default     = 4096

  validation {
    condition     = var.control_plane_memory_mb >= 2048
    error_message = "Control-plane требует минимум 2048 МБ RAM (требование kubeadm)."
  }
}

# ------- Ресурсы worker-нод -----------------------------------

variable "worker_cpus" {
  description = "Количество vCPU для каждой worker-ноды."
  type        = number
  default     = 2
}

variable "worker_memory_mb" {
  description = "Оперативная память каждой worker-ноды в МБ. 4096 необходимо для EFK (Elasticsearch требует 2+ GB)."
  type        = number
  default     = 4096
}

# ------- Сетевые настройки ------------------------------------

variable "control_plane_ip" {
  description = "Статический IP-адрес control-plane ноды в host-only сети VirtualBox."
  type        = string
  default     = "192.168.56.10"
}

variable "worker_ips" {
  description = "Список статических IP-адресов для worker-нод. Порядок: [worker-01, worker-02]."
  type        = list(string)
  default     = ["192.168.56.11", "192.168.56.12"]

  validation {
    condition     = length(var.worker_ips) == 2
    error_message = "Должно быть ровно 2 worker-ноды."
  }
}

variable "subnet_mask" {
  description = "Маска подсети для host-only сети."
  type        = string
  default     = "255.255.255.0"
}

variable "gateway" {
  description = "Шлюз по умолчанию."
  type        = string
  default     = "192.168.56.1"
}

# ------- Диск ------------------------------------------------

variable "disk_size_gb" {
  description = "Размер системного диска в ГБ. 20 GB — минимум для K8s + образов Docker."
  type        = number
  default     = 20
}
