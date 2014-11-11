#!/bin/sh

updatedb

rm -f /etc/dpkg/dpkg.cfg.d/02apt-speedup

apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

rm /etc/apt/apt.conf.d/40squid-deb-proxy

# TODO: unwind the unsafe keys?
