#!/bin/bash
set -x ; set -e ; date


cat > /etc/lipstick.properties <<EOF
lipstick.index     = lipstick
cluster.name       = lipstick_cluster
discovery.type     = list
elasticsearch.urls = $ES_PORT_9300_TCP_ADDR
transport.tcp.port = $ES_PORT_9300_TCP_PORT
EOF

cd $LIPSTICK_DIR

git checkout master

cat /etc/lipstick.properties

./gradlew run-app
