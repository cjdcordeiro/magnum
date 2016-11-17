#!/bin/sh

. /etc/sysconfig/heat-params

CONF_FILE=/etc/systemd/system/swarm-node-exporter.service

cat > $CONF_FILE << EOF
[Unit]
Description=Swarm node-exporter
After=docker.service
Requires=docker.service
OnFailure=swarm-node-exporter-failure.service

[Service]
ExecStartPre=-/usr/bin/docker kill swarm-node-exporter
ExecStartPre=-/usr/bin/docker rm -f swarm-node-exporter
ExecStartPre=-/usr/bin/docker pull prom/node-exporter
ExecStart=/usr/bin/docker run -e http_proxy=$HTTP_PROXY \\
                              -e https_proxy=$HTTPS_PROXY \\
                              -e no_proxy=$NO_PROXY \\
                              --publish=9100:9100 \\
                              --name swarm-node-exporter \\
                              prom/node-exporter
ExecStop=/usr/bin/docker stop swarm-node-exporter

[Install]
WantedBy=multi-user.target
EOF

chown root:root $CONF_FILE
chmod 644 $CONF_FILE
