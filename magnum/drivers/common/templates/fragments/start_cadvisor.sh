#!/bin/sh

. /etc/sysconfig/heat-params

if [ "$(echo $MONITORING_ENABLED | tr '[:upper:]' '[:lower:]')" = "false" ]; then
  exit 0
fi

/usr/bin/docker rm -f cadvisor || /usr/bin/docker pull google/cadvisor:latest

/usr/bin/docker run -e http_proxy=$HTTP_PROXY \\
                              -e https_proxy=$HTTPS_PROXY \\
                              -e no_proxy=$NO_PROXY \\
                              --volume=/:/rootfs:ro \\
                              --volume=/var/run:/var/run:rw \\
                              --volume=/sys:/sys:ro \\
                              --volume=/var/lib/docker/:/var/lib/docker:ro \\
                              --publish=8080:8080 \\
                              --name swarm-cadvisor \\
                              google/cadvisor:latest
