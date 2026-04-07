#!/usr/bin/env bash
# =============================================================
# k8s/logging/setup-es-users.sh
# Создаёт пользователей в Elasticsearch после его запуска
#
# ПОЧЕМУ отдельный скрипт, а не initContainer:
#   initContainer в StatefulSet запускается ДО основного контейнера
#   на той же ноде, но НЕ имеет доступа к localhost:9200 ES —
#   ES ещё не запущен. Нужен внешний вызов после Ready.
#
# ЗАПУСК (после install-efk.sh, когда ES перешёл в Ready):
#   ./k8s/logging/setup-es-users.sh
# =============================================================

set -euo pipefail
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

MONITORING_NS="monitoring"
ES_SVC="elasticsearch-master"

# ── Читаем пароли из Secrets ──────────────────────────────────
log "Читаем пароли из K8s Secrets..."
ELASTIC_PASSWORD=$(kubectl get secret elasticsearch-credentials \
  -n "$MONITORING_NS" -o jsonpath='{.data.password}' | base64 -d)
KIBANA_PASSWORD=$(kubectl get secret kibana-credentials \
  -n "$MONITORING_NS" -o jsonpath='{.data.password}' | base64 -d)
FLUENTD_PASSWORD=$(kubectl get secret fluentd-credentials \
  -n "$MONITORING_NS" -o jsonpath='{.data.password}' | base64 -d)

# ── Ждём готовности ES ────────────────────────────────────────
log "Ожидаем готовности Elasticsearch..."
kubectl wait pod \
  -n "$MONITORING_NS" \
  -l app=elasticsearch-master \
  --for=condition=Ready \
  --timeout=300s

# ── Запускаем временный pod для вызовов API ───────────────────
# Используем kubectl exec в под ES вместо port-forward,
# чтобы не зависеть от сетевого доступа с хоста.
ES_POD=$(kubectl get pod -n "$MONITORING_NS" \
  -l app=elasticsearch-master \
  -o jsonpath='{.items[0].metadata.name}')

log "Используем под: $ES_POD"

# Функция: выполнить curl внутри пода ES
es_curl() {
  kubectl exec -n "$MONITORING_NS" "$ES_POD" -- \
    curl -sk \
      -u "elastic:${ELASTIC_PASSWORD}" \
      -H "Content-Type: application/json" \
      "$@"
}

# ── 1. Установить пароль kibana_system ────────────────────────
log "Устанавливаем пароль kibana_system..."
es_curl -X POST "https://localhost:9200/_security/user/kibana_system/_password" \
  -d "{\"password\":\"${KIBANA_PASSWORD}\"}"
echo ""

# ── 2. Создать роль logstash_writer для Fluentd ───────────────
log "Создаём роль logstash_writer..."
es_curl -X PUT "https://localhost:9200/_security/role/logstash_writer" \
  -d '{
    "cluster": ["monitor", "manage_index_templates", "manage_ilm"],
    "indices": [{
      "names": ["app-logs-*", "system-logs-*"],
      "privileges": ["write", "create", "create_index", "manage", "auto_configure"]
    }]
  }'
echo ""

# ── 3. Создать пользователя logstash_internal ─────────────────
log "Создаём пользователя logstash_internal (для Fluentd)..."
es_curl -X PUT "https://localhost:9200/_security/user/logstash_internal" \
  -d "{
    \"password\": \"${FLUENTD_PASSWORD}\",
    \"roles\": [\"logstash_writer\"],
    \"full_name\": \"Fluentd Internal User\"
  }"
echo ""

# ── 4. Проверка ───────────────────────────────────────────────
log "Проверяем созданных пользователей..."
es_curl "https://localhost:9200/_security/user/kibana_system" | \
  grep -o '"username":"[^"]*"'
es_curl "https://localhost:9200/_security/user/logstash_internal" | \
  grep -o '"username":"[^"]*"'

# ── 5. Добавление Elasticsearch сертификатов ─────────────────
log "Добавление Elasticsearch сертификатов..."
kubectl get secret elasticsearch-master-certs \
  -n monitoring \
  -o jsonpath='{.data.ca\.crt}' | base64 -d > "${CERTS_DIR}/es-master-ca.crt"
kubectl create secret generic elasticsearch-tls \
  --from-file=es-master-ca.crt="${CERTS_DIR}/es-master-ca.crt"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Пользователи созданы!"
echo "  Следующий шаг:"
echo "    helm upgrade --install kibana elastic/kibana \\"
echo "      --namespace monitoring \\"
echo "      --version 8.5.1 \\"
echo "      -f k8s/logging/kibana-values.yaml"
echo "═══════════════════════════════════════════════════════"
