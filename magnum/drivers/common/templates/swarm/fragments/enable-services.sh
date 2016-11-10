#!/bin/sh

echo "starting services"
systemctl daemon-reload
for service in $NODE_SERVICES; do
    if [ "$service" = "swarm-cadvisor" ] && \\
      [ "$(echo $MONITORING_ENABLED | tr '[:upper:]' '[:lower:]')" = "false" ]; then
        continue
    fi
    echo "activating service $service"
    systemctl enable $service
    systemctl --no-block start $service
done

setenforce 1
