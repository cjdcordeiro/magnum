#!/bin/sh

. /etc/sysconfig/heat-params

if [ "$(echo $MONITORING_ENABLED | tr '[:upper:]' '[:lower:]')" = "false" ]; then
  exit 0
fi

if [ -f /usr/local/bin/start-prometheus-grafana ]; then
  POST_SCRIPT="ExecStartPost=-/usr/local/bin/start-prometheus-grafana"
else
  POST_SCRIPT=""
fi

CONF_FILE=/etc/systemd/system/cadvisor.service

cat > $CONF_FILE << EOF
[Unit]
Description=cadvisor
After=docker.service
Requires=docker.service
OnFailure=cadvisor-failure.service

[Service]
TimeoutStartSec=1800
ExecStartPre=-/usr/bin/docker kill cadvisor
ExecStartPre=-/usr/bin/docker rm cadvisor
ExecStartPre=-/usr/bin/docker pull google/cadvisor:latest
ExecStart=/usr/bin/docker run -e http_proxy=$HTTP_PROXY \\
                              -e https_proxy=$HTTPS_PROXY \\
                              -e no_proxy=$NO_PROXY \\
                              --volume=/:/rootfs:ro \\
                              --volume=/var/run:/var/run:rw \\
                              --volume=/sys:/sys:ro \\
                              --volume=/var/lib/docker/:/var/lib/docker:ro \\
                              --publish=8080:8080 \\
                              --name cadvisor \\
                              google/cadvisor:latest
ExecStop=/usr/bin/docker stop cadvisor
$POST_SCRIPT

[Install]
WantedBy=multi-user.target
EOF

chown root:root $CONF_FILE
chmod 644 $CONF_FILE
