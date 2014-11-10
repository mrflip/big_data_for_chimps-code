#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Java
#

echo oracle-java7-installer shared/accepted-oracle-license-v1-1 select true | \
  /usr/bin/debconf-set-selections

$safe_apt_install oracle-java7-installer oracle-java7-set-default
