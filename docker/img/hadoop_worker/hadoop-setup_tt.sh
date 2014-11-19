#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Nodemanager -- supervises job execution
#

# Install, forcing use of the specific common version
$safe_apt_install -t $HADOOP_APT_VERSION hadoop-0.20-mapreduce-tasktracker

# Directories
#
mkdir -p            $HADOOP_BULK_DIR/mapred $HADOOP_BULK_DIR/jobstatus $HADOOP_LOG_DIR/hadoop-0.20-mapreduce/history
chown mapred:hadoop $HADOOP_BULK_DIR/mapred $HADOOP_BULK_DIR/jobstatus $HADOOP_LOG_DIR/hadoop-0.20-mapreduce/history
chmod 775           $HADOOP_BULK_DIR/mapred $HADOOP_BULK_DIR/jobstatus $HADOOP_LOG_DIR/hadoop-0.20-mapreduce/history

mkdir   $HADOOP_LOG_DIR/tasktracker-daemon
ln -snf $HADOOP_LOG_DIR/tasktracker-daemon

# update the ports and directories not handled by mustache_rider
#
perl -p -i -e 's~/var/log~'$HADOOP_LOG_DIR'~g'  /etc/default/hadoop*    
