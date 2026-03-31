#!/usr/bin/env bash
# =============================================================
# k8s/monitoring/install-monitoring.sh
#
# Устанавливает полный стек мониторинга через один Helm Chart:
#   kube-prometheus-stack = Prometheus + Grafana + AlertManager
#                         + Node Exporter + kube-state-metrics
#
# ЗАПУСК:
#   chmod +x k8s/monitoring/install-monitoring.sh
#   ./k8s/monitoring/install-monitoring.sh
#
# ПОСЛЕ УСТАНОВКИ:
#   Grafana:       http://<NODE_IP>:30030  (admin / prom-operator)
#   Prometheus:    http://<NODE_IP>:30090
#   AlertManager:  http://<NODE_IP>:30093
# =============================================================

set -euo pipefail
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

MONITORING_NS="monitoring"

# ── 1. Namespace ─────────────────────────────────────────────
log "Создание namespace $MONITORING_NS..."
kubectl create namespace "$MONITORING_NS" --dry-run=client -o yaml | kubectl apply -f -

# ── 2. Helm репозиторий ───────────────────────────────────────
log "Добавление Helm репозитория prometheus-community..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# ── 3. Установка kube-prometheus-stack ───────────────────────
log "Установка kube-prometheus-stack..."
helm upgrade --install kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace "$MONITORING_NS" \
  --version "55.5.0" \
  -f k8s/monitoring/prometheus-values.yaml \
  --wait \
  --timeout 10m

log "kube-prometheus-stack установлен!"

# ── 4. Применить PrometheusRule для DevTracker ───────────────
log "Применение PrometheusRule для DevTracker..."
kubectl apply -f k8s/monitoring/prometheus-rules.yaml

# ── 5. Применить AlertManager конфигурацию ──────────────────
log "Применение AlertManager конфигурации..."
kubectl apply -f k8s/monitoring/alertmanager-config.yaml

# ── 6. Вывод информации ──────────────────────────────────────
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
GRAFANA_PASS=$(kubectl get secret -n "$MONITORING_NS" \
  kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d)

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Мониторинг установлен!"
echo "═══════════════════════════════════════════════════════"
echo "  Grafana:      http://${NODE_IP}:30030"
echo "  Login:        admin / ${GRAFANA_PASS}"
echo ""
echo "  Prometheus:   http://${NODE_IP}:30090"
echo "  AlertManager: http://${NODE_IP}:30093"
echo ""
echo "  Рекомендуемые дашборды для импорта:"
echo "    1860  — Node Exporter Full"
echo "    6417  — Kubernetes Cluster Monitoring"
echo "    14584 — ArgoCD"
echo "    11159 — Node.js Application Dashboard"
echo "═══════════════════════════════════════════════════════"
