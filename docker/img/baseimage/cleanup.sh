#!/bin/sh

updatedb

rm -f /etc/dpkg/dpkg.cfg.d/02apt-speedup

rm /etc/apt/apt.conf.d/40squid-deb-proxy
