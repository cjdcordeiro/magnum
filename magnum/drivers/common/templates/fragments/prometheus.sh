#!/bin/sh

. /etc/sysconfig/heat-params

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
SERVICE_DISCOVERY_FILE_MOUNTED=$PROMETHEUS_SHARE_MOUNT"/service_discovery.yml"

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

SERVICE_DISCOVERY_CRON=$PROMETHEUS_SHARE"/cron.d"
mkdir $SERVICE_DISCOVERY_CRON
echo "PROM_SD_CRON=$SERVICE_DISCOVERY_CRON" >> /etc/sysconfig/prometheus-conf-setup

SD_CRONJOB=$SERVICE_DISCOVERY_CRON"/prometheus-sd-cron"
cat > $SD_CRONJOB <<CRON_EOF
* * * * * $PROMETHEUS_SHARE_MOUNT/prometheus-sd-cron &> /dev/null
CRON_EOF

SD_REAL_JOB=$PROMETHEUS_SHARE"/prometheus-sd"
cat > $SD_REAL_JOB <<SD_EOF
#!/bin/sh
# We assume /etc/docker and /etc/sysconfig/heat-params are accessible
. /etc/sysconfig/heat-params
CLUSTER_CA='/etc/docker/ca.crt'
SERVER_CERTIFICATE='/etc/docker/server.crt'
SERVER_KEY='/etc/docker/server.key'

NODES=\`docker -H $API_IP_ADDRESS:2376 --tlsverify --tlscacert $CLUSTER_CA \\
                --tlskey $SERVER_KEY --tlscert $SERVER_CERTIFICATE \\
                ps | tail -n +2 | awk '{print \$NF}' | awk -F'/' '{print \$1}' | sort | uniq\`

NEW_SD_FILE_CONTENT="- targets:\n"
for node in \$NODES
do
  NEW_SD_FILE_CONTENT=\$NEW_SD_FILE_CONTENT"  - \$node:8080\n  - \$node:9100\n"
done
NEW_SD_FILE_CONTENT=\$NEW_SD_FILE_CONTENT"  labels:\n  job: magnum-prometheus"

echo \$NEW_SD_FILE_CONTENT > $SERVICE_DISCOVERY_FILE_MOUNTED
SD_EOF

chmod 755 $SD_REAL_JOB
