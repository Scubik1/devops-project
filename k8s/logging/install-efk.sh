#!/usr/bin/env bash
# =============================================================
# k8s/logging/install-efk.sh
# Установка стека EFK через Helm
#
# ИЗМЕНЕНИЯ v3:
#   - helm uninstall перед установкой если релиз существует
#     (избегает ошибки "duplicate entries" при повторном запуске)
#   - ELASTIC_PASSWORD передаётся через --set, а не через values
#     (chart сам добавляет env в контейнер — дублировать нельзя)
#
# ЗАПУСК:
#   chmod +x k8s/logging/install-efk.sh
#   ./k8s/logging/install-efk.sh
# =============================================================

set -euo pipefail
GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $1"; }

MONITORING_NS="monitoring"

# ── Читаем пароль elastic из Secret ──────────────────────────
# Secret создан скриптом prepare-efk-secrets.sh
ELASTIC_PASSWORD=$(kubectl get secret elasticsearch-credentials \
  -n "$MONITORING_NS" \
  -o jsonpath='{.data.password}' | base64 -d)

# ── Helm репозитории ──────────────────────────────────────────
log "Добавление Helm репозиториев..."
helm repo add elastic https://helm.elastic.co
helm repo add fluent  https://fluent.github.io/helm-charts
helm repo update

# ── Elasticsearch ─────────────────────────────────────────────
# Если релиз уже существует — сносим его перед установкой.
# Это нужно чтобы избежать ошибки "duplicate entries" при
# изменении структуры StatefulSet (Kubernetes не умеет
# мержить изменения в env/volumeMounts через patch).
if helm status elasticsearch -n "$MONITORING_NS" &>/dev/null; then
  log "Удаляем существующий релиз elasticsearch..."
  helm uninstall elasticsearch -n "$MONITORING_NS"
  # Ждём полного удаления подов
  kubectl wait pod \
    -n "$MONITORING_NS" \
    -l app=elasticsearch-master \
    --for=delete \
    --timeout=120s 2>/dev/null || true
fi

log "Установка Elasticsearch..."
helm upgrade --install elasticsearch elastic/elasticsearch \
  --namespace "$MONITORING_NS" \
  --version "8.5.1" \
  -f k8s/logging/elasticsearch-values.yaml \
  --set "secret.password=${ELASTIC_PASSWORD}" \
  --wait \
  --timeout 10m

log "Elasticsearch установлен!"

# ── Kibana ────────────────────────────────────────────────────
log "Установка Kibana..."
helm upgrade --install kibana elastic/kibana \
  --namespace "$MONITORING_NS" \
  --version "8.5.1" \
  -f k8s/logging/kibana-values.yaml \
  --wait \
  --timeout 5m

log "Kibana установлена!"

# ── Fluentd ───────────────────────────────────────────────────
log "Установка Fluentd (DaemonSet)..."
helm upgrade --install fluentd fluent/fluentd \
  --namespace "$MONITORING_NS" \
  --version "0.5.2" \
  -f k8s/logging/fluentd-values.yaml \
  --wait \
  --timeout 5m

log "Fluentd установлен!"

# ── Создать пользователей ES (kibana_system, logstash_internal)
log "Создание пользователей в Elasticsearch..."
k8s/logging/setup-es-users.sh

# ── Итог ──────────────────────────────────────────────────────
NODE_IP=$(kubectl get nodes \
  -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  EFK стек установлен!"
echo "═══════════════════════════════════════════════════════"
echo "  Kibana: http://${NODE_IP}:30056"
echo "  Login:  elastic / ${ELASTIC_PASSWORD}"
echo ""
echo "  Следующие шаги в Kibana:"
echo "  1. Stack Management → Index Patterns"
echo "  2. Создать: fluentd-*  (поле: @timestamp)"
echo "  3. Discover → fluentd-* → фильтр: kubernetes.namespace_name : staging"
echo "═══════════════════════════════════════════════════════"
