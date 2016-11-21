#!/bin/sh

START_PROMETHEUS='/usr/local/bin/start-prometheus-grafana'

cat >$START_PROMETHEUS <<EOF
#!/bin/sh
. /etc/sysconfig/heat-params
. /etc/sysconfig/prometheus-conf-setup

# Setup the API client for swarm
CLUSTER_CA='/etc/docker/ca.crt'
SERVER_CERTIFICATE='/etc/docker/server.crt'
SERVER_KEY='/etc/docker/server.key'

while [ \`docker -H \$API_IP_ADDRESS:2376 --tlsverify --tlscacert \$CLUSTER_CA \\
                          --tlskey \$SERVER_KEY --tlscert \$SERVER_CERTIFICATE \\
                          info | grep 'Nodes:' | awk '{print \$2}'\` -lt 1 ]
do
  echo 'Waiting for available nodes...'
  sleep 5
done

# Following will fail if already exists
docker -H \$API_IP_ADDRESS:2376 --tlsverify --tlscacert \$CLUSTER_CA \\
                          --tlskey \$SERVER_KEY --tlscert \$SERVER_CERTIFICATE \\
                          run -t -p 9090:9090 \\
                          -v \$PROM_CONF_DIR_HOST:\$PROM_CONF_DIR_CONTAINER:z \\
                          -v /prometheus --link cadvisor:cadvisor \\
                          --link node-exporter:node-exporter \\
                          -e constraint:node==\`hostname -s\` \\
                          --name prometheus prom/prometheus \\
                          -config.file=\$PROM_CONF_DIR_CONTAINER'/prometheus.yml' \\
                          -storage.local.path=/prometheus

docker -H \$API_IP_ADDRESS:2376 --tlsverify --tlscacert \$CLUSTER_CA \\
                          --tlskey \$SERVER_KEY --tlscert \$SERVER_CERTIFICATE \\
                          run -t -p 3000:3000 -v /var/lib/grafana:/var/lib/grafana \\
                          -e constraint:node==\`hostname -s\` \\
                          -e "GF_SECURITY_ADMIN_PASSWORD=admin" \\
                          --name grafana grafana/grafana

docker -H \$API_IP_ADDRESS:2376 --tlsverify --tlscacert \$CLUSTER_CA \\
                          --tlskey \$SERVER_KEY --tlscert \$SERVER_CERTIFICATE \\
                          run -t -v /etc/docker:/etc/docker \\
                          -v /etc/sysconfig:/etc/sysconfig \\
                          -v $PROM_SD_CRON:/etc/cron.d/
                          -v \$PROM_CONF_DIR_HOST:\$PROM_CONF_DIR_CONTAINER:z \\
                          -e constraint:node==\`hostname -s\` \\
                          --name prometheus_auto_sd fedora
EOF

chown root:root $START_PROMETHEUS
chmod 755 $START_PROMETHEUS
