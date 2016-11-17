#!/bin/sh

. /etc/sysconfig/heat-params

if [ "$(echo $MONITORING_ENABLED | tr '[:upper:]' '[:lower:]')" = "false" ]; then
  exit 0
fi

/usr/bin/docker rm -f node-exporter || /usr/bin/docker pull prom/node-exporter

/usr/bin/docker run -e http_proxy=$HTTP_PROXY \\
                              -e https_proxy=$HTTPS_PROXY \\
                              -e no_proxy=$NO_PROXY \\
                              --publish=9100:9100 \\
                              --name swarm-node-exporter \\
                              prom/node-exporter
