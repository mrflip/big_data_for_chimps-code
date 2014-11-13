#!/bin/sh

git config --global user.email "nobody@bigdataforchimps.com"
git config --global user.name "bd4c docker -- dummy git entry for root"

updatedb

rm -rf /build

rm -f /etc/dpkg/dpkg.cfg.d/02apt-speedup

apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

rm /etc/apt/apt.conf.d/40squid-deb-proxy

# TODO: unwind the unsafe keys?
