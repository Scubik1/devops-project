#!/usr/bin/env bash
# =============================================================
# scripts/bootstrap-cluster.sh
# Полная установка кластера с нуля
#
# ПОРЯДОК ВЫПОЛНЕНИЯ (строго соблюдать!):
#   1. Terraform    — создать ВМ
#   2. Ansible      — настроить ноды
#   3. kubeadm      — инициализировать K8s
#   4. Calico       — установить CNI
#   5. Namespaces   — создать namespace
#   6. Helm Chart   — задеплоить приложение
#   7. ArgoCD       — установить GitOps
#   8. Мониторинг   — Prometheus + Grafana
#   9. Логирование  — EFK
#
# ПРЕДВАРИТЕЛЬНЫЕ ТРЕБОВАНИЯ:
#   - VirtualBox установлен
#   - Terraform установлен: terraform version
#   - Ansible установлен:   ansible --version
#   - Helm установлен:      helm version
#   - kubectl установлен:   kubectl version
#   - SSH ключ создан:      ls ~/.ssh/k8s_rsa
#   - terraform.tfvars заполнен (cp terraform/terraform.tfvars.example terraform/terraform.tfvars)
#
# ЗАПУСК:
#   chmod +x scripts/bootstrap-cluster.sh
#   ./scripts/bootstrap-cluster.sh
# =============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

log()     { echo -e "${GREEN}[✓]${NC} $1"; }
step()    { echo -e "\n${BLUE}${BOLD}══ $1 ══${NC}"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
err()     { echo -e "${RED}[✗] ОШИБКА: $1${NC}"; exit 1; }
confirm() {
  read -rp "$(echo -e "${YELLOW}[?]${NC} $1 [y/N] ")" ans
  [[ "$ans" =~ ^[Yy]$ ]] || { warn "Пропущено"; return 1; }
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ────────────────────────────────────────────────────────────
step "Проверка предварительных требований"
# ────────────────────────────────────────────────────────────

for cmd in terraform ansible helm kubectl; do
  command -v "$cmd" &>/dev/null || err "$cmd не найден. Установите его."
  log "$cmd доступен: $(command -v $cmd)"
done

[[ -f ~/.ssh/k8s_rsa ]] || err "SSH ключ ~/.ssh/k8s_rsa не найден. Создайте: ssh-keygen -t ed25519 -f ~/.ssh/k8s_rsa"
[[ -f "$PROJECT_DIR/terraform/terraform.tfvars" ]] || \
  err "terraform.tfvars не найден. Скопируйте: cp terraform/terraform.tfvars.example terraform/terraform.tfvars и заполните"

# ────────────────────────────────────────────────────────────
step "Этап 1: Terraform — создание виртуальных машин"
# ────────────────────────────────────────────────────────────

cd "$PROJECT_DIR/terraform"

log "Инициализация Terraform (скачивание провайдера)..."
terraform init

log "Показ плана изменений..."
terraform plan -out=tfplan

confirm "Создать виртуальные машины? (terraform apply)" || exit 0

terraform apply tfplan
log "ВМ созданы!"

# Экспорт IP-адресов для Ansible
CONTROL_PLANE_IP=$(terraform output -raw control_plane_ip)
log "Control-plane IP: $CONTROL_PLANE_IP"

# ────────────────────────────────────────────────────────────
step "Этап 2: Ожидание запуска ВМ"
# ────────────────────────────────────────────────────────────

log "Ожидание доступности SSH на всех нодах (до 3 минут)..."
for ip in $CONTROL_PLANE_IP 192.168.56.11 192.168.56.12; do
  for i in $(seq 1 18); do
    if ssh -i ~/.ssh/k8s_rsa -o StrictHostKeyChecking=no \
       -o ConnectTimeout=5 ubuntu@"$ip" true 2>/dev/null; then
      log "SSH доступен: $ip"
      break
    fi
    echo "  Ожидание $ip... ($i/18)"
    sleep 10
  done
done

# ────────────────────────────────────────────────────────────
step "Этап 3: Ansible — настройка нод"
# ────────────────────────────────────────────────────────────

cd "$PROJECT_DIR/ansible"

log "Проверка доступности нод через Ansible..."
ansible all -m ping

log "Запуск Ansible playbook..."
ansible-playbook site.yml -v

log "Ноды настроены!"

# ────────────────────────────────────────────────────────────
step "Этап 4: kubeadm — инициализация кластера"
# ────────────────────────────────────────────────────────────

log "Инициализация control-plane через kubeadm..."
ssh -i ~/.ssh/k8s_rsa ubuntu@"$CONTROL_PLANE_IP" << 'ENDSSH'
  set -e
  sudo kubeadm init \
    --control-plane-endpoint "192.168.56.10:6443" \
    --pod-network-cidr "192.168.0.0/16" \
    --apiserver-advertise-address "192.168.56.10" \
#    --upload-certs \
    2>&1 | tee /tmp/kubeadm-init.log

  # Настроить kubectl
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # Сохранить join-команду
#  grep "kubeadm join" /tmp/kubeadm-init.log -A 2 > /tmp/join-command.sh
  kubeadm token create --print-join-command > /tmp/join-command.sh
  echo "kubeadm init завершён!"
ENDSSH

# Скачать kubeconfig на хост-машину
log "Скачивание kubeconfig..."
scp -i ~/.ssh/k8s_rsa ubuntu@"$CONTROL_PLANE_IP":/home/ubuntu/.kube/config \
  ~/.kube/config-devtracker
export KUBECONFIG=~/.kube/config-devtracker
log "kubeconfig сохранён в ~/.kube/config-devtracker"

# ────────────────────────────────────────────────────────────
step "Этап 5: Calico CNI"
# ────────────────────────────────────────────────────────────

helm repo add projectcalico https://docs.tigera.io/calico/charts
helm repo update

helm upgrade --install calico projectcalico/tigera-operator \
  --namespace tigera-operator \
  --create-namespace \
  --version v3.27.0 \
  --set installation.cni.type=Calico \
  --wait --timeout 5m

log "Ожидание готовности Calico..."
kubectl wait --for=condition=Ready pods -n calico-system --all --timeout=120s
log "Calico установлен!"

# ────────────────────────────────────────────────────────────
step "Этап 6: Подключение worker нод"
# ────────────────────────────────────────────────────────────

# Получить join-команду
JOIN_CMD=$(ssh -i ~/.ssh/k8s_rsa ubuntu@"$CONTROL_PLANE_IP" cat /tmp/join-command.sh)

for worker_ip in 192.168.56.11 192.168.56.12; do
  log "Подключение worker $worker_ip..."
  ssh -i ~/.ssh/k8s_rsa ubuntu@"$worker_ip" "sudo $JOIN_CMD"
  log "Worker $worker_ip подключён!"
done

log "Ожидание готовности всех нод..."
kubectl wait --for=condition=Ready nodes --all --timeout=120s
kubectl get nodes -o wide
log "Все ноды Ready!"

# ────────────────────────────────────────────────────────────
step "Этап 7: Namespace и вспомогательные компоненты"
# ────────────────────────────────────────────────────────────

kubectl apply -f "$PROJECT_DIR/k8s/namespaces/namespaces.yaml"

# Metrics Server (нужен для HPA)
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Local Path Provisioner (StorageClass для PVC)
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

# Секрет для pull образов из GitLab Registry
warn "Создайте секрет для GitLab Registry:"
warn "kubectl create secret docker-registry gitlab-registry-secret \\"
warn "  --docker-server=registry.gitlab.com \\"
warn "  --docker-username=<your-gitlab-user> \\"
warn "  --docker-password=<your-access-token> \\"
warn "  -n staging && kubectl apply -n prod ..."

log "Namespace и вспомогательные компоненты установлены!"

# ────────────────────────────────────────────────────────────
step "Этап 8: NGINX Ingress Controller"
# ────────────────────────────────────────────────────────────

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30080 \
  --wait --timeout 3m
log "NGINX Ingress Controller установлен!"

# ────────────────────────────────────────────────────────────
step "Итог"
# ────────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Кластер Kubernetes готов!"
echo "═══════════════════════════════════════════════════════"
echo ""
echo "  СЛЕДУЮЩИЕ ШАГИ:"
echo ""
echo "  1. Создать секрет GitLab Registry (см. выше)"
echo ""
echo "  2. Задеплоить приложение:"
echo "     helm upgrade --install devtracker ./helm \\"
echo "       -f helm/values-staging.yaml \\"
echo "       --set backend.image.tag=latest \\"
echo "       --set backend.secrets.dbPassword='<DB_PASS>' \\"
echo "       --set backend.secrets.jwtSecret='<JWT_SECRET>' \\"
echo "       --set postgres.password='<DB_PASS>' \\"
echo "       -n staging"
echo ""
echo "  3. Установить ArgoCD:"
echo "     ./argocd/install.sh"
echo ""
echo "  4. Установить мониторинг:"
echo "     ./k8s/monitoring/install-monitoring.sh"
echo ""
echo "  5. Установить логирование EFK:"
echo "     ./k8s/logging/install-efk.sh"
echo ""
echo "  Приложение будет доступно по:"
echo "  http://$CONTROL_PLANE_IP:30080"
echo "═══════════════════════════════════════════════════════"
