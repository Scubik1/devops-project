#cloud-config
# =============================================================
# cloud-init.tpl — шаблон начальной конфигурации ВМ
#
# Cloud-init выполняется при ПЕРВОМ старте ВМ.
# Terraform передаёт переменные через templatefile().
#
# Что делает этот скрипт:
#   1. Устанавливает hostname
#   2. Создаёт пользователя ubuntu с sudo-правами
#   3. Прописывает SSH-ключ (нужен для Ansible)
#   4. Настраивает статический IP на втором сетевом адаптере
#   5. Отключает swap (обязательное требование kubeadm)
#   6. Настраивает timezone
# =============================================================

# Имя хоста — важно для K8s (ноды идентифицируются по hostname)
hostname: ${hostname}
fqdn: ${hostname}.local

# Создание пользователя
users:
  - name: ubuntu
    gecos: Ubuntu User
    sudo: ALL=(ALL) NOPASSWD:ALL   # sudo без пароля (нужно для Ansible)
    shell: /bin/bash
    ssh_authorized_keys:
      - ${ssh_public_key}          # ← вставляется Terraform

# Настройка сети через netplan (Ubuntu 22.04 использует netplan)
write_files:
  - path: /etc/netplan/01-hostonly.yaml
    permissions: '0600'
    content: |
      network:
        version: 2
        ethernets:
          # Адаптер 1: NAT (enp0s3) — оставляем DHCP
          enp0s3:
            dhcp4: true

          # Адаптер 2: Host-Only (enp0s8) — статический IP
          enp0s8:
            addresses:
              - ${ip_address}/24
            routes:
              - to: 192.168.56.0/24
                via: ${gateway}
            nameservers:
              addresses: [8.8.8.8, 8.8.4.4]

# Команды, выполняемые при первом старте
runcmd:
  # Применить настройки сети
  - netplan apply

  # Отключить swap — ОБЯЗАТЕЛЬНО для kubeadm
  # kubeadm откажется инициализировать кластер если swap включён
  - swapoff -a
  - sed -i '/swap/d' /etc/fstab

  # Установить временную зону
  - timedatectl set-timezone Europe/Moscow

  # Обновить /etc/hosts для взаимного разрешения имён нод
  - |
    cat >> /etc/hosts << 'EOF'
    ${ip_address}  ${hostname}
    192.168.56.10  k8s-control-plane
    192.168.56.11  k8s-worker-01
    192.168.56.12  k8s-worker-02
    EOF

  # Создать директорию для SSH-ключей (на случай если не создана)
  - mkdir -p /home/ubuntu/.ssh
  - chown -R ubuntu:ubuntu /home/ubuntu/.ssh
  - chmod 700 /home/ubuntu/.ssh

# Установить базовые пакеты
packages:
  - curl
  - wget
  - apt-transport-https
  - ca-certificates
  - gnupg
  - lsb-release
  - net-tools

# Обновить пакеты при первом старте
package_update: true
package_upgrade: false   # Полное обновление делает Ansible (ansible-upgrade.yml)

# Сигнал об успешном выполнении
final_message: "Cloud-init для ${hostname} завершён. Система готова к настройке через Ansible."
