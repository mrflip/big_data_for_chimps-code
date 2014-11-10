#!/bin/sh
set -e ; set -x  # live verbosely, die easily


# ---------------------------------------------------------------------------
#
# Setup a deb proxy. Only 
#

# Basics so we can use the deb-proxy cache
$safe_apt_install squid-deb-proxy-client

# Figure out the IP address of docker host
route -n | awk '/^0.0.0.0/ {print $2}' > /tmp/docker_host_ip

# Use the deb-proxy cacher if available. It's not worth doing earlier because the apt-update stuff isn't cached.
rm /etc/apt/apt.conf.d/30autoproxy
echo "Acquire::http::Proxy \"http://`cat /tmp/docker_host_ip`:10000\";" > /etc/apt/apt.conf.d/40squid-deb-proxy

