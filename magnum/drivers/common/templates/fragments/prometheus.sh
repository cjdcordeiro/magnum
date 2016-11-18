#!/bin/sh

if [ "$(echo $MONITORING_ENABLED | tr '[:upper:]' '[:lower:]')" = "false" ]; then
  exit 0
fi

# Create a shared directory on every node, with the conf file
PROMETHEUS_SHARE="/opt/prometheus"
mkdir -p $PROMETHEUS_SHARE
echo "PROM_CONF_DIR_HOST=$PROMETHEUS_SHARE" > /etc/sysconfig/prometheus-conf-setup

PROMETHEUS_SHARE_MOUNT="/prometheus-data"
echo "PROM_CONF_DIR_CONTAINER=$PROMETHEUS_SHARE_MOUNT" >> /etc/sysconfig/prometheus-conf-setup

PROMETHEUS_CONF=$PROMETHEUS_SHARE"/prometheus.yml"
SERVICE_DISCOVERY_FILE=$PROMETHEUS_SHARE"/service_discovery.yml"
touch $SERVICE_DISCOVERY_FILE
SERVICE_DISCOVERY_FILE_MOUNTED=$PROMETHEUS_SHARE_MOUNT"/prometheus.yml"

cat > $PROMETHEUS_CONF << CONF_EOF
global:
  scrape_interval: 10s
  evaluation_interval: 15s
  scrape_timeout: 10s

scrape_configs:
  - job_name: 'magnum-prometheus'
    file_sd_configs:
      - files:
        - $SERVICE_DISCOVERY_FILE_MOUNTED
CONF_EOF

# Populate an initial basic service discovery
cat > $SERVICE_DISCOVERY_FILE << SD_EOF
- targets:
  - cadvisor:8080
  - node-exporter:9100
  labels:
    job: magnum-prometheus
SD_EOF
