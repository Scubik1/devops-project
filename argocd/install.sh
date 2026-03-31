#!/usr/bin/env bash
# =============================================================
# argocd/install.sh — скрипт установки ArgoCD в кластер
#
# ЗАПУСК (после инициализации кластера):
#   chmod +x argocd/install.sh
#   ./argocd/install.sh
#
# ЧТО ДЕЛАЕТ СКРИПТ:
#   1. Создаёт namespace argocd
#   2. Устанавливает ArgoCD через Helm (официальный chart)
#   3. Ждёт готовности подов ArgoCD
#   4. Получает начальный пароль admin
#   5. Создаёт ArgoCD Applications для staging и prod
#   6. Добавляет GitLab репозиторий в ArgoCD
# =============================================================

set -euo pipefail   # Прерваться при ошибке, неопределённых переменных и в pipeline

# Цвета для вывода
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Переменные ────────────────────────────────────────────────
ARGOCD_NAMESPACE="argocd"
ARGOCD_VERSION="5.51.6"           # Версия Helm chart
GITLAB_REPO_URL="${1:-https://gitlab.com/yourorg/devtracker.git}"
GITLAB_TOKEN="${GITLAB_TOKEN:-}"   # Токен GitLab для приватного репозитория

# ── 1. Создать namespace ─────────────────────────────────────
log "Создание namespace $ARGOCD_NAMESPACE..."
kubectl create namespace "$ARGOCD_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# ── 2. Добавить Helm репозиторий ArgoCD ──────────────────────
log "Добавление Helm репозитория ArgoCD..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# ── 3. Установить ArgoCD ─────────────────────────────────────
log "Установка ArgoCD v${ARGOCD_VERSION}..."
helm upgrade --install argocd argo/argo-cd \
  --namespace "$ARGOCD_NAMESPACE" \
  --version "$ARGOCD_VERSION" \
  --set server.service.type=NodePort \
  --set server.service.nodePortHttp=30080 \
  --set configs.params."server\.insecure"=true \
  --wait \
  --timeout 5m

log "ArgoCD установлен!"

# ── 4. Ждать готовности podов ────────────────────────────────
log "Ожидание готовности подов ArgoCD..."
kubectl wait --for=condition=Ready pods \
  --all -n "$ARGOCD_NAMESPACE" \
  --timeout=120s

# ── 5. Получить начальный пароль admin ───────────────────────
ADMIN_PASSWORD=$(kubectl -n "$ARGOCD_NAMESPACE" get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

log "ArgoCD admin password: ${ADMIN_PASSWORD}"
warn "СОХРАНИТЕ ПАРОЛЬ! Смените его после первого входа."

# ── 6. Добавить GitLab репозиторий ───────────────────────────
if [ -n "$GITLAB_TOKEN" ]; then
  log "Добавление GitLab репозитория в ArgoCD..."
  # Создать Secret с учётными данными репозитория
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: devtracker-repo
  namespace: $ARGOCD_NAMESPACE
  labels:
    argocd.argoproj.io/secret-type: repository
type: Opaque
stringData:
  type: git
  url: $GITLAB_REPO_URL
  password: $GITLAB_TOKEN
  username: oauth2
EOF
  log "Репозиторий добавлен!"
else
  warn "GITLAB_TOKEN не задан — добавьте репозиторий вручную в ArgoCD UI"
fi

# ── 7. Создать ArgoCD Applications ───────────────────────────
log "Создание ArgoCD Applications..."

# Заменить URL репозитория на реальный
sed "s|https://gitlab.com/yourorg/devtracker.git|$GITLAB_REPO_URL|g" \
  argocd/apps/staging.yaml | kubectl apply -f -

sed "s|https://gitlab.com/yourorg/devtracker.git|$GITLAB_REPO_URL|g" \
  argocd/apps/prod.yaml | kubectl apply -f -

log "ArgoCD Applications созданы!"

# ── 8. Итоговая информация ────────────────────────────────────
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
echo ""
echo "═══════════════════════════════════════════════════════"
echo "  ArgoCD успешно установлен!"
echo "═══════════════════════════════════════════════════════"
echo "  URL:      http://${NODE_IP}:30080"
echo "  Login:    admin"
echo "  Password: ${ADMIN_PASSWORD}"
echo ""
echo "  Добавьте в /etc/hosts:"
echo "  ${NODE_IP}  argocd.local"
echo ""
echo "  Проверить статус:"
echo "  kubectl get applications -n argocd"
echo "═══════════════════════════════════════════════════════"
