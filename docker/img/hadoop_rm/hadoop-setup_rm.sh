#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Resourcemanager
#

# Install, forcing use of the cloudera repos (so that ubuntu zookeeper isn't preferred)
$safe_apt_install -t $HADOOP_APT_VERSION \
  hadoop-yarn-resourcemanager hadoop-mapreduce-historyserver

# update the ports and directories not handled by mustache_rider
perl -p -i -e 's~/var/log~'$HADOOP_LOG_DIR'~g'          /etc/default/hadoop*    
