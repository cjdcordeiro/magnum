#!/bin/sh

. /etc/sysconfig/heat-params

if [ "$(echo $MONITORING_ENABLED | tr '[:upper:]' '[:lower:]')" = "false" ]; then
  exit 0
fi

CONF_FILE=/etc/systemd/system/node-exporter.service

cat > $CONF_FILE << EOF
[Unit]
Description=node-exporter
After=docker.service
Requires=docker.service
OnFailure=node-exporter-failure.service

[Service]
TimeoutStartSec=300
ExecStartPre=-/usr/bin/docker kill node-exporter
ExecStartPre=-/usr/bin/docker rm node-exporter
ExecStartPre=-/usr/bin/docker pull prom/node-exporter
ExecStart=/usr/bin/docker run -e http_proxy=$HTTP_PROXY \\
                              -e https_proxy=$HTTPS_PROXY \\
                              -e no_proxy=$NO_PROXY \\
                              --publish=9100:9100 \\
                              --name node-exporter \\
                              prom/node-exporter:0.12.0
ExecStop=/usr/bin/docker stop node-exporter

[Install]
WantedBy=multi-user.target
EOF

chown root:root $CONF_FILE
chmod 644 $CONF_FILE
