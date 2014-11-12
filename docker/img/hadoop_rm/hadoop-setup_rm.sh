#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Resourcemanager
#

# Install, forcing use of the specific common version
$safe_apt_install -t $HADOOP_APT_VERSION \
  hadoop-yarn-resourcemanager hadoop-mapreduce-historyserver

# Directories
#
mkdir -p            $HADOOP_BULK_DIR/jobstatus
chown mapred:mapred $HADOOP_BULK_DIR/jobstatus

# update the ports and directories not handled by mustache_rider
perl -p -i -e 's~/var/log~'$HADOOP_LOG_DIR'~g'          /etc/default/hadoop*    
