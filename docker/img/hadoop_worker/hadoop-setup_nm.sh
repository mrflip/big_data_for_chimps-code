#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Nodemanager -- supervises job execution
#

# Install, forcing use of the specific common version
$safe_apt_install -t $HADOOP_APT_VERSION hadoop-yarn-nodemanager

mkdir -p            $HADOOP_BULK_DIR/jobstatus $HADOOP_LOCL_DIR/mapred $HADOOP_LOCL_DIR/yarn-jobs $HADOOP_LOCL_DIR/yarn-staging
chown mapred:mapred $HADOOP_BULK_DIR/jobstatus $HADOOP_LOCL_DIR/mapred
chown yarn:yarn     $HADOOP_LOCL_DIR/yarn-jobs $HADOOP_LOCL_DIR/yarn-staging

# update the ports and directories not handled by mustache_rider
perl -p -i -e 's~/var/log~'$HADOOP_LOG_DIR'~g'  /etc/default/hadoop*    
