#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Resourcemanager
#

# Install, forcing use of the specific common version
$safe_apt_install -t $HADOOP_APT_VERSION \
  hadoop-0.20-mapreduce-jobtracker

# Directories
#

mkdir   $HADOOP_LOG_DIR/jobtracker-daemon
# ln -snf $HADOOP_LOG_DIR/jobtracker-daemon   /var/log/hadoop-mapred/

mkdir -p            $HADOOP_LOG_DIR/hadoop-0.20-mapreduce/history $HADOOP_BULK_DIR/mapred
chown mapred:hadoop $HADOOP_LOG_DIR/hadoop-0.20-mapreduce/history $HADOOP_BULK_DIR/mapred
chmod 775           $HADOOP_LOG_DIR/hadoop-0.20-mapreduce/history $HADOOP_BULK_DIR/mapred


ls -l /var/log /etc/default

# update the ports and directories not handled by mustache_rider
perl -p -i -e 's~/var/log~'$HADOOP_LOG_DIR'~g' /etc/default/hadoop*    


