#!/bin/bash

echo "🔄 Resetting Elastic Stack and reprocessing all logs..."

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Funzione per stampare messaggi colorati
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 1. Fermare lo stack
print_status "Stopping Elastic Stack..."
docker-compose down

# 2. Pulire i dati Elasticsearch (ATTENZIONE: cancella tutti i dati!)
print_warning "Clearing Elasticsearch data..."
if [ -d "./data/elasticsearch" ]; then
    rm -rf ./data/elasticsearch/*
    print_status "Elasticsearch data cleared"
else
    print_warning "No Elasticsearch data directory found"
fi

# 3. Pulire i dati Kibana
print_status "Clearing Kibana data..."
if [ -d "./data/kibana" ]; then
    rm -rf ./data/kibana/*
    print_status "Kibana data cleared"
else
    print_warning "No Kibana data directory found"
fi

# 4. Rimuovere container e volumi orfani
print_status "Cleaning up Docker containers and volumes..."
docker-compose down --volumes --remove-orphans
docker system prune -f

# 5. Verificare la configurazione
print_status "Validating configuration files..."

# Verifica che tutti i file di configurazione esistano
CONFIG_FILES=(
    "config/logstash/logstash.yml"
    "config/logstash/pipeline/main.conf"
    "config/filebeat/filebeat.yml"
    "config/elasticsearch/elasticsearch.yml"
    "config/kibana/kibana.yml"
)

for file in "${CONFIG_FILES[@]}"; do
    if [ -f "$file" ]; then
        print_status "✓ $file exists"
    else
        print_error "✗ $file missing!"
        exit 1
    fi
done

# 6. Avviare lo stack
print_status "Starting Elastic Stack..."
docker-compose up -d

# 7. Attendere che i servizi siano pronti
print_status "Waiting for services to be ready..."

# Aspetta Elasticsearch
print_status "Waiting for Elasticsearch..."
until curl -s -u ${ELASTIC_USERNAME:-elastic}:${ELASTIC_PASSWORD} http://localhost:9200/_cluster/health > /dev/null 2>&1; do
    sleep 5
    echo -n "."
done
echo ""
print_status "✓ Elasticsearch is ready"

# Aspetta Logstash
print_status "Waiting for Logstash..."
until curl -s http://localhost:9600/_node/stats > /dev/null 2>&1; do
    sleep 5
    echo -n "."
done
echo ""
print_status "✓ Logstash is ready"

# Aspetta Kibana
print_status "Waiting for Kibana..."
until curl -s http://localhost:5601/api/status > /dev/null 2>&1; do
    sleep 5
    echo -n "."
done
echo ""
print_status "✓ Kibana is ready"

# 8. Verificare che il pipeline principale sia caricato
print_status "Checking Logstash pipeline..."
sleep 10  # Aspetta che il pipeline sia caricato

PIPELINES=$(curl -s http://localhost:9600/_node/pipelines | jq -r '.pipelines | keys[]' 2>/dev/null || echo "")

if echo "$PIPELINES" | grep -q "main"; then
    print_status "✓ Main pipeline loaded (handles all log types with routing)"
else
    print_warning "⚠ Main pipeline not found"
fi

# 9. Verificare gli indici
print_status "Checking Elasticsearch indices..."
sleep 5

INDICES=$(curl -s -u ${ELASTIC_USERNAME:-elastic}:${ELASTIC_PASSWORD} http://localhost:9200/_cat/indices?v 2>/dev/null || echo "")

if [ -n "$INDICES" ]; then
    echo "$INDICES"
else
    print_warning "No indices found yet. Logs will be created as they are processed."
fi

# 10. Informazioni finali
echo ""
print_status "🎉 Reset completed successfully!"
echo ""
echo "📊 Access your services:"
echo "   • Kibana: http://localhost:5601"
echo "   • Elasticsearch: http://localhost:9200"
echo ""
echo "📋 Pipeline routing:"
echo "   • All logs → main pipeline (single port 5044)"
echo "   • Apache Access logs → apache-access-project1-YYYY.MM.DD"
echo "   • Apache Error logs → apache-error-project1-YYYY.MM.DD"  
echo "   • PHP Error logs → php-error-project1-YYYY.MM.DD"
echo ""
echo "🔍 Expected indices:"
echo "   • apache-access-project1-YYYY.MM.DD"
echo "   • apache-error-project1-YYYY.MM.DD"
echo "   • php-error-project1-YYYY.MM.DD"
echo ""
print_warning "Note: Indices will be created automatically when logs are processed."
print_status "You can now start sending logs to be processed by the new pipelines!"
