#!/bin/sh

if [ "$(echo $MONITORING_ENABLED | tr '[:upper:]' '[:lower:]')" = "false" ]; then
  exit 0
fi

. /etc/sysconfig/heat-params
. /etc/sysconfig/prometheus-conf-setup

# Setup the API client for swarm
CLUSTER_CA="/etc/docker/ca.crt"
SERVER_CERTIFICATE="/etc/docker/server.crt"
SERVER_KEY="/etc/docker/server.key"

docker -H $API_IP_ADDRESS:2376 --tlsverify --tlscacert $CLUSTER_CA \
                          --tlskey $SERVER_KEY --tlscert $SERVER_CERTIFICATE \
                          run -t -p 9090:9090 \
                          -v $PROM_CONF_DIR_HOST:$PROM_CONF_DIR_CONTAINER:z \
                          -v /prometheus --link cadvisor:cadvisor \
                          --link node-exporter:node-exporter \
                          --name prometheus prom/prometheus \
                          -config.file=$PROM_CONF_DIR_CONTAINER"/prometheus.yml" \
                          -storage.local.path=/prometheus
