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

prom_status=\$(docker -H \$API_IP_ADDRESS:2376 --tlsverify --tlscacert \$CLUSTER_CA \\
                  --tlskey \$SERVER_KEY --tlscert \$SERVER_CERTIFICATE \\
                  inspect --format="{{ .State.Running }}" prometheus)

# prometheus container might already exist
if [ \$? -eq 0 ]; then
  # If not running, delete it
  if [ \$prom_status != "true" ]; then
    docker -H \$API_IP_ADDRESS:2376 --tlsverify --tlscacert \$CLUSTER_CA \\
                      --tlskey \$SERVER_KEY --tlscert \$SERVER_CERTIFICATE \\
                      rm -f prometheus
  else
    exit 0
  fi
fi

# Following will fail if already exists
docker -H \$API_IP_ADDRESS:2376 --tlsverify --tlscacert \$CLUSTER_CA \\
                          --tlskey \$SERVER_KEY --tlscert \$SERVER_CERTIFICATE \\
                          run -t -d -p 9090:9090 \\
                          -v \$PROM_CONF_DIR_HOST:\$PROM_CONF_DIR_CONTAINER:z \\
                          -v /prometheus --name prometheus prom/prometheus \\
                          -config.file=\$PROM_CONF_DIR_CONTAINER'/prometheus.yml' \\
                          -storage.local.path=/prometheus



docker -H \$API_IP_ADDRESS:2376 --tlsverify --tlscacert \$CLUSTER_CA \\
                          --tlskey \$SERVER_KEY --tlscert \$SERVER_CERTIFICATE \\
                          run -t -d -v /etc/docker:/etc/docker \\
                          -v \$PROM_CONF_DIR_HOST:\$PROM_CONF_DIR_CONTAINER:z \\
                          -e affinity:container==prometheus \\
                          fedora sh /prometheus-data/prometheus-sd-job.sh


# Grafana might suffer from https://github.com/docker/docker/pull/21222 in v1.10
# make sure cadvisor doesn't fail because of it
docker -H \$API_IP_ADDRESS:2376 --tlsverify --tlscacert \$CLUSTER_CA \\
                          --tlskey \$SERVER_KEY --tlscert \$SERVER_CERTIFICATE \\
                          run -t -d -p 3000:3000 \\
                          -e affinity:container==prometheus \\
                          -e "GF_SECURITY_ADMIN_PASSWORD=$GRAFANA_ADMIN_PASSWD" \\
                          grafana/grafana

PROMETHEUS_IP=\`docker -H \$API_IP_ADDRESS:2376 --tlsverify --tlscacert \$CLUSTER_CA  \\
                          --tlskey \$SERVER_KEY --tlscert \$SERVER_CERTIFICATE \\
                          inspect prometheus | python -c \\
                          "import sys, json; print json.load(sys.stdin)[0]['NetworkSettings']['IPAddress']"\`

curl --user admin:$GRAFANA_ADMIN_PASSWD -X POST \\
                          -H 'Content-Type: application/json;charset=UTF-8' \\
                          --data-binary \\
                          '{"name":"Swarm Monitoring","isDefault":true,
                            "type":"prometheus","url":"http://\$PROMETHEUS_IP:9090",
                            "access":"direct"}' "http://\$PROMETHEUS_IP:3000/api/datasources/"
EOF

chown root:root $START_PROMETHEUS
chmod 755 $START_PROMETHEUS
