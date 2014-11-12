#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Nodemanager -- supervises job execution
#

# Install, forcing use of the specific common version
$safe_apt_install -t $HADOOP_APT_VERSION hadoop-yarn-nodemanager

# Directories
#
mkdir -p            $HADOOP_BULK_DIR/jobstatus  $HADOOP_BULK_DIR/mapred
chown mapred:hadoop $HADOOP_BULK_DIR/jobstatus  $HADOOP_BULK_DIR/mapred
mkdir -p            $HADOOP_BULK_DIR/yarn-local $HADOOP_LOG_DIR/yarn-containers
chown yarn:hadoop   $HADOOP_BULK_DIR/yarn-local $HADOOP_LOG_DIR/yarn-containers
chmod 775           $HADOOP_BULK_DIR/yarn-local $HADOOP_LOG_DIR/yarn-containers

mkdir   $HADOOP_LOG_DIR/nodemanager-daemon
ln -snf $HADOOP_LOG_DIR/nodemanager-daemon       /var/log/hadoop-yarn/nodemanager-daemon

# update the ports and directories not handled by mustache_rider
#
perl -p -i -e 's~/var/log~'$HADOOP_LOG_DIR'~g'  /etc/default/hadoop*    
