#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Nodemanager -- supervises job execution
#

# Install, forcing use of the specific common version
$safe_apt_install -t $HADOOP_APT_VERSION hadoop-yarn-nodemanager

mkdir -p            $HADOOP_BULK_DIR/jobstatus $HADOOP_BULK_DIR/mapred
chown mapred:mapred $HADOOP_BULK_DIR/jobstatus $HADOOP_BULK_DIR/mapred
mkdir -p            $HADOOP_BULK_DIR/yarn-jobs $HADOOP_LOG_DIR/yarn-containers
chown yarn:yarn     $HADOOP_BULK_DIR/yarn-jobs $HADOOP_LOG_DIR/yarn-containers

# update the ports and directories not handled by mustache_rider
perl -p -i -e 's~/var/log~'$HADOOP_LOG_DIR'~g'  /etc/default/hadoop*    
