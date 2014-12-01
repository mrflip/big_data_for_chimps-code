#!/bin/bash

banner='\n  *\n  * '
set +e # don't fail on errors
set -x # do be talkative

echo -e "$banner" " ~~~ Environment Variables ~~~ " "$banner"

# Dump the current env var set
echo "Environment variables associated with HADOOP|TCP|UDP|PORT|ADDR|DIR:"
env | egrep 'HADOOP|TCP|UDP|PORT|ADDR|DIR|HOSTNAME' | egrep -v 'ENV' | sort || true

echo -e "$banner" " ~~~ Ulimit ~~~ " "$banner"

ulimit -a

echo -e "$banner" " ~~~ Network Info ~~~ " "$banner"

host -v -t A `hostname` || true
/sbin/ifconfig          || true
cat /etc/hostname       || true
echo "$HOSTNAME"
hostname
uname -a
getent hosts $HOSTNAME
