#!/bin/sh

. /etc/sysconfig/heat-params

CONF_FILE=/etc/systemd/system/swarm-cadvisor.service

cat > $CONF_FILE << EOF
[Unit]
Description=Swarm cadvisor
After=docker.service
Requires=docker.service
OnFailure=swarm-cadvisor-failure.service

[Service]
ExecStartPre=-/usr/bin/docker kill swarm-cadvisor
ExecStartPre=-/usr/bin/docker rm -f swarm-cadvisor
ExecStartPre=-/usr/bin/docker pull google/cadvisor:latest
ExecStart=/usr/bin/docker run -e http_proxy=$HTTP_PROXY \\
                              -e https_proxy=$HTTPS_PROXY \\
                              -e no_proxy=$NO_PROXY \\
                              --volume=/:/rootfs:ro \\
                              --volume=/var/run:/var/run:rw \\
                              --volume=/sys:/sys:ro \\
                              --volume=/var/lib/docker/:/var/lib/docker:ro \\
                              --publish=8080:8080 \\
                              --name swarm-cadvisor \\
                              google/cadvisor:latest
ExecStop=/usr/bin/docker stop swarm-cadvisor

[Install]
WantedBy=multi-user.target
EOF

chown root:root $CONF_FILE
chmod 644 $CONF_FILE
