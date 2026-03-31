# =============================================================
# modules/vm/variables.tf — входные параметры модуля vm
#
# Модуль vm/ описывает ОДНУ виртуальную машину.
# Он вызывается три раза из корневого main.tf через for_each.
# Каждый вызов создаёт ВМ с уникальными параметрами.
# =============================================================

variable "vm_name" {
  description = "Имя ВМ в VirtualBox (должно быть уникальным)."
  type        = string
}

variable "cpus" {
  description = "Количество виртуальных CPU."
  type        = number
  default     = 2
}

variable "memory" {
  description = "Объём RAM в МБ."
  type        = number
  default     = 4096
}

variable "image_path" {
  description = "Путь к OVA/VMDK образу Ubuntu 22.04."
  type        = string
}

variable "ip_address" {
  description = "Статический IP-адрес ВМ в сети host-only."
  type        = string
}

variable "subnet_mask" {
  description = "Маска подсети."
  type        = string
  default     = "255.255.255.0"
}

variable "gateway" {
  description = "Шлюз по умолчанию."
  type        = string
}

variable "ssh_public_key" {
  description = "Публичный SSH-ключ, который будет добавлен в authorized_keys."
  type        = string
}

variable "role" {
  description = "Роль ноды: control-plane или worker."
  type        = string

  validation {
    condition     = contains(["control-plane", "worker"], var.role)
    error_message = "role должна быть 'control-plane' или 'worker'."
  }
}

variable "cluster_name" {
  description = "Имя кластера — используется как тег."
  type        = string
}
