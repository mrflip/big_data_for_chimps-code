#!/bin/sh

mkdir /bulk/deb_proxy/cache /bulk/deb_proxy/log
chown -R proxy.proxy /bulk/deb_proxy

. /usr/share/squid-deb-proxy/init-common.sh
pre_start

exec /usr/sbin/squid3 -N -f /etc/squid-deb-proxy/squid-deb-proxy.conf
