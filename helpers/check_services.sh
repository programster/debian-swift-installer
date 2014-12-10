#!/bin/bash
SERVICES=()
SERVICES+=("glance-api")
SERVICES+=("glance-registry")

SERVICES+=("cinder-api")
SERVICES+=("cinder-scheduler")

SERVICES+=("nova-api")
SERVICES+=("nova-cert")
SERVICES+=("nova-conductor")
SERVICES+=("nova-consoleauth")
SERVICES+=("nova-novncproxy")
SERVICES+=("nova-scheduler")
SERVICES+=("nova-spicehtml5proxy")
SERVICES+=("nova-xenvncproxy")

SERVICES+=("keystone")

SERVICES+=("neutron-server")


for VAR_NAME in "${SERVICES[@]}"
do
    :
        sudo service $VAR_NAME status
done