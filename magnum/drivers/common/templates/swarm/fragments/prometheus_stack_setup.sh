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

cat > $PROMETHEUS_CONF <<CONF_EOF
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
cat > $SERVICE_DISCOVERY_FILE <<SD_EOF
- targets:
  - cadvisor:8080
  - node-exporter:9100
  labels:
    job: magnum-prometheus
SD_EOF


SD_JOB=$PROMETHEUS_SHARE"/prometheus-sd-job.sh"
SD_PARSER=$PROMETHEUS_SHARE"/prometheus-sd-parser.py"
cat > $SD_JOB <<SD_EOF
#!/bin/bash

# Keep the job running
while true
do
  info=\`curl --silent --cacert /etc/docker/ca.crt \\
      --key /etc/docker/server.key \\
      --cert /etc/docker/server.crt \\
      https://$API_IP_ADDRESS:2376/info\`
  python3 $PROMETHEUS_SHARE_MOUNT/prometheus-sd-parser.py \\
      --info="\$info" --sd_file=$SERVICE_DISCOVERY_FILE_MOUNTED
  sleep 120
done
SD_EOF

chmod 755 $SD_JOB

cat > $SD_PARSER <<SD_PARSER_EOF
import argparse
import json

def parser():
    parser = argparse.ArgumentParser(description='Prometheus SD parse cluster nodes')
    parser.add_argument('--info', '-i', type=str, nargs='?', default="",
              help='json output from cluster info')
    parser.add_argument('--sd_file', '-f', type=str, nargs='?', default="$SERVICE_DISCOVERY_FILE_MOUNTED",
              help='SD YAML file where to write to')

    args = parser.parse_args()
    return args

def flat_list_and_find_ips(info_json, nodes=[]):
    for el in info_json:
        if isinstance(el, list):
            flat_list_and_find_ips(el, nodes)
        else:
            # The non-TLS port comes with the nodes ips
            # This can be changed for Docker API 1.24
            # where querying the nodes is possible
            if isinstance(el, str) and ":2375" in el:
                nodes.append(el.split(":")[0])

if __name__ == '__main__':
    args=parser()
    jinfo = json.loads(args.info)
    node_list = []
    flat_list_and_find_ips(jinfo.values(), node_list)
    with open(args.sd_file, 'w') as sdf:
        sdf.write("- targets:\n")
        for node in node_list:
            sdf.write("  - %s:8080\n" % node)
            sdf.write("  - %s:9100\n" % node)
        sdf.write("  labels:\n    job: magnum-prometheus\n")
SD_PARSER_EOF

# setup a directory for grafana
# mkdir -p /var/lib/grafana
