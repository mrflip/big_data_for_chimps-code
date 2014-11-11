#!/bin/sh
set -e ; set -x

#
# Runit services should live in /etc/sv and be symlinked into /etc/service
#
mkdir -p /etc/sv
mv  /etc/service/* /etc/sv/

# Only re-enable sshd (not cron or syslog)
ln -s /etc/sv/sshd /etc/service/sshd

# Install mush, a neat little templating tool that turns environment variables into mustaches (http://mustache.github.io)
( cd /tmp &&
  git clone https://github.com/jwerle/mush.git &&
  cd mush &&
  make install )
