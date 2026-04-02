#!/usr/bin/env bash
# =============================================================
# k8s/logging/install-efk.sh
# Установка стека EFK через Helm
#
# EFK = Elasticsearch + Fluentd + Kibana
#
# ПОЧЕМУ EFK, а НЕ Loki?
#   ТЗ v2.1 явно указывает EFK. В enterprise среде EFK
#   используется шире — полнотекстовый поиск по логам,
#   богатый UI Kibana, мощные фильтры в Fluentd.
#   Недостаток: Elasticsearch требует 2+ GB RAM.
#
# КОМПОНЕНТЫ:
#   Elasticsearch — NoSQL база данных для хранения логов
#   Fluentd       — агент сбора логов (DaemonSet на каждой ноде)
#   Kibana        — веб-интерфейс для поиска и визуализации логов
#
# ЗАПУСК:
#   chmod +x k8s/logging/install-efk.sh
#   ./k8s/logging/install-efk.sh
# =============================================================

set -euo pipefail
GREEN='\033[0;32m'; NC='\033[0m'
log() { echo -e "${GREEN}[INFO]${NC} $1"; }

MONITORING_NS="monitoring"

# ── 1. Добавить Helm репозиторий Elastic ─────────────────────
log "Добавление Helm репозитория Elastic..."
#helm repo add elastic https://helm.elastic.co
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add fluent  https://fluent.github.io/helm-charts
helm repo update

# ── 2. Установить Elasticsearch ──────────────────────────────
log "Установка Elasticsearch..."
helm upgrade --install elasticsearch bitnami/elasticsearch \
  --namespace "$MONITORING_NS" \
  --version "21.2.2" \
  -f k8s/logging/elasticsearch-values.yaml \
  --wait \
  --timeout 10m

log "Elasticsearch установлен!"

# ── 3. Установить Kibana ─────────────────────────────────────
log "Установка Kibana..."
helm upgrade --install kibana bitnami/kibana \
  --namespace "$MONITORING_NS" \
  --version "11.2.5" \
  -f k8s/logging/kibana-values.yaml \
  --wait \
  --timeout 5m

log "Kibana установлена!"

# ── 4. Установить Fluentd ─────────────────────────────────────
log "Установка Fluentd (DaemonSet)..."
helm upgrade --install fluentd fluent/fluentd \
  --namespace "$MONITORING_NS" \
  --version "0.5.2" \
  -f k8s/logging/fluentd-values.yaml \
  --wait \
  --timeout 5m

log "Fluentd установлен!"

# ── 5. Вывод информации ───────────────────────────────────────
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  EFK стек установлен!"
echo "═══════════════════════════════════════════════════════"
echo "  Kibana: http://${NODE_IP}:30056"
echo ""
echo "  Следующие шаги в Kibana:"
echo "  1. Перейти: Stack Management → Index Patterns"
echo "  2. Создать index pattern: fluentd-* (поле: @timestamp)"
echo "  3. Перейти: Discover → выбрать fluentd-*"
echo "  4. Фильтр: kubernetes.namespace_name : staging"
echo "═══════════════════════════════════════════════════════"
