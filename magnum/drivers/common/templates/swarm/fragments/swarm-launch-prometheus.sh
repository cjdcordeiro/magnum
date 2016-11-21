#!/bin/sh

. /etc/sysconfig/heat-params
. /etc/sysconfig/prometheus-conf-setup

START_PROMETHEUS="/usr/local/bin/start-prometheus"
cat >$START_PROMETHEUS << EOF
# Setup the API client for swarm
CLUSTER_CA="/etc/docker/ca.crt"
SERVER_CERTIFICATE="/etc/docker/server.crt"
SERVER_KEY="/etc/docker/server.key"

while [ `docker -H $API_IP_ADDRESS:2376 --tlsverify --tlscacert $CLUSTER_CA \
                          --tlskey $SERVER_KEY --tlscert $SERVER_CERTIFICATE \
                          info | grep "Nodes:" | awk -F' ' '{print $2}'` -lt 1 ]
do
  echo "Waiting for available nodes..."
  sleep 5
done

# Following will fail if already exists
docker -H $API_IP_ADDRESS:2376 --tlsverify --tlscacert $CLUSTER_CA \
                          --tlskey $SERVER_KEY --tlscert $SERVER_CERTIFICATE \
                          run -t -p 9090:9090 \
                          -v $PROM_CONF_DIR_HOST:$PROM_CONF_DIR_CONTAINER:z \
                          -v /prometheus --link cadvisor:cadvisor \
                          --link node-exporter:node-exporter \
                          --name prometheus prom/prometheus \
                          -config.file=$PROM_CONF_DIR_CONTAINER"/prometheus.yml" \
                          -storage.local.path=/prometheus
EOF

chown root:root $START_PROMETHEUS
chmod 755 $START_PROMETHEUS
