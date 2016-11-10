#!/bin/sh

. /etc/sysconfig/heat-params

if [ "$(echo $MONITORING_ENABLED | tr '[:upper:]' '[:lower:]')" = "false" ]; then
    exit 0
fi

sudo docker run \
  --volume=/:/rootfs:ro \
  --volume=/var/run:/var/run:rw \
  --volume=/sys:/sys:ro \
  --volume=/var/lib/docker/:/var/lib/docker:ro \
  --publish=8080:8080 \
  --detach=true \
  --name=cadvisor \
  google/cadvisor:latest
