#!/usr/bin/env bash
# =============================================================
# k8s/logging/prepare-efk-secrets.sh
# Создаёт K8s Secrets и TLS сертификаты перед установкой EFK
#
# ЗАПУСК:
#   chmod +x k8s/logging/prepare-efk-secrets.sh
#   ./k8s/logging/prepare-efk-secrets.sh
#
# ЧТО СОЗДАЁТСЯ:
#   - TLS сертификаты (CA + node cert) для Elasticsearch
#   - Secret elasticsearch-tls   — сертификаты
#   - Secret elasticsearch-credentials — пароль elastic (superuser)
#   - Secret kibana-credentials        — пароль kibana_system
#   - Secret kibana-encryption-keys    — ключи шифрования Kibana
#   - Secret fluentd-credentials       — пароль logstash_internal
#
# ТРЕБОВАНИЯ:
#   - Docker (для генерации сертификатов через образ Elasticsearch)
#   - kubectl с доступом к кластеру
#   - openssl
# =============================================================

set -euo pipefail
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
log()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

MONITORING_NS="monitoring"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"
ES_IMAGE="docker.elastic.co/elasticsearch/elasticsearch:8.5.1"

# ── Генерация случайных паролей ────────────────────────────────
# В production замените на vault или sealed-secrets!
ELASTIC_PASSWORD=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 20)
KIBANA_PASSWORD=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 20)
FLUENTD_PASSWORD=$(openssl rand -base64 20 | tr -dc 'a-zA-Z0-9' | head -c 20)

# ── 1. Namespace ───────────────────────────────────────────────
log "Создание namespace $MONITORING_NS..."
kubectl create namespace "$MONITORING_NS" --dry-run=client -o yaml | kubectl apply -f -

# ── 2. Генерация TLS сертификатов ─────────────────────────────
log "Генерация TLS сертификатов..."
mkdir -p "$CERTS_DIR"
chmod 777 "$CERTS_DIR"

# Шаг 2.1: создать Certificate Authority (CA)
docker run --rm \
  -v "${CERTS_DIR}:/certs" \
  "$ES_IMAGE" \
  bin/elasticsearch-certutil ca \
    --out /certs/elastic-stack-ca.p12 \
    --pass "" \
    --silent

# Шаг 2.2: создать сертификат ноды подписанный CA
docker run --rm \
  -v "${CERTS_DIR}:/certs" \
  "$ES_IMAGE" \
  bin/elasticsearch-certutil cert \
    --ca /certs/elastic-stack-ca.p12 \
    --ca-pass "" \
    --out /certs/elastic-certificates.p12 \
    --pass "" \
    --silent

# Шаг 2.3: экспортировать в PEM формат (для Kibana и Fluentd)
openssl pkcs12 \
  -in "${CERTS_DIR}/elastic-certificates.p12" \
  -out "${CERTS_DIR}/elastic.crt" \
  -nokeys \
  -passin pass:""

openssl pkcs12 \
  -in "${CERTS_DIR}/elastic-certificates.p12" \
  -out "${CERTS_DIR}/elastic.key" \
  -nocerts \
  -nodes \
  -passin pass:""

chmod 600 "${CERTS_DIR}/elastic.key"
log "Сертификаты созданы в ${CERTS_DIR}/"

# ── 3. Secret с сертификатами ──────────────────────────────────
log "Создание Secret elasticsearch-tls..."
kubectl create secret generic elasticsearch-tls \
  --from-file=elastic.crt="${CERTS_DIR}/elastic.crt" \
  --from-file=elastic.key="${CERTS_DIR}/elastic.key" \
  --from-file=elastic-stack-ca.p12="${CERTS_DIR}/elastic-stack-ca.p12" \
  --namespace "$MONITORING_NS" \
  --dry-run=client -o yaml | kubectl apply -f -

# ── 4. Secret с паролями ───────────────────────────────────────
log "Создание Secret elasticsearch-credentials..."
kubectl create secret generic elasticsearch-credentials \
  --from-literal=username=elastic \
  --from-literal=password="${ELASTIC_PASSWORD}" \
  --namespace "$MONITORING_NS" \
  --dry-run=client -o yaml | kubectl apply -f -

log "Создание Secret kibana-credentials..."
kubectl create secret generic kibana-credentials \
  --from-literal=username=kibana_system \
  --from-literal=password="${KIBANA_PASSWORD}" \
  --namespace "$MONITORING_NS" \
  --dry-run=client -o yaml | kubectl apply -f -

log "Создание Secret kibana-encryption-keys..."
kubectl create secret generic kibana-encryption-keys \
  --from-literal=encryptionKey="$(openssl rand -hex 16)" \
  --from-literal=encryptedSavedObjects="$(openssl rand -hex 16)" \
  --from-literal=reportingEncryptionKey="$(openssl rand -hex 16)" \
  --namespace "$MONITORING_NS" \
  --dry-run=client -o yaml | kubectl apply -f -

log "Создание Secret fluentd-credentials..."
kubectl create secret generic fluentd-credentials \
  --from-literal=username=logstash_internal \
  --from-literal=password="${FLUENTD_PASSWORD}" \
  --namespace "$MONITORING_NS" \
  --dry-run=client -o yaml | kubectl apply -f -

# ── 5. Сохранить пароли локально ──────────────────────────────
PASSWORDS_FILE="$(dirname "$0")/generated-passwords.txt"
cat > "$PASSWORDS_FILE" <<EOF
# СГЕНЕРИРОВАННЫЕ ПАРОЛИ EFK — $(date)
# НЕ КОММИТИТЬ В GIT! Добавить в .gitignore!

ELASTIC_PASSWORD=${ELASTIC_PASSWORD}
KIBANA_PASSWORD=${KIBANA_PASSWORD}
FLUENTD_PASSWORD=${FLUENTD_PASSWORD}

# Kibana URL:     http://<NODE_IP>:30056
# Kibana login:   elastic / ${ELASTIC_PASSWORD}
EOF
chmod 600 "$PASSWORDS_FILE"

echo ""
echo "═══════════════════════════════════════════════════════"
echo "  Secrets созданы!"
echo "═══════════════════════════════════════════════════════"
echo "  Пароль elastic:          ${ELASTIC_PASSWORD}"
echo "  Пароль kibana_system:    ${KIBANA_PASSWORD}"
echo "  Пароль logstash_internal:${FLUENTD_PASSWORD}"
echo ""
echo "  Пароли сохранены в: ${PASSWORDS_FILE}"
echo "  ⚠️  Добавьте generated-passwords.txt в .gitignore!"
echo ""
echo "  Следующий шаг:"
echo "    ./k8s/logging/install-efk.sh"
echo "═══════════════════════════════════════════════════════"
