#!/bin/sh
set -e ; set -x


echo "**********" ; du --exclude=proc -smc /

# ---------------------------------------------------------------------------
#
# Java
#

echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | \
  /usr/bin/debconf-set-selections

$safe_apt_install oracle-java7-installer oracle-java7-set-default

echo "**********" ; du --exclude=proc -smc /

rm /var/cache/oracle-jdk7-installer/jdk-*-linux-x64.tar.gz
apt-get clean

echo "**********" ; du --exclude=proc -smc /
