#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Namenod
#

# Install, forcing use of the cloudera repos (so that ubuntu zookeeper isn't preferred)
$safe_apt_install -t $HADOOP_APT_VERSION hadoop-hdfs-datanode

# ---------------------------------------------------------------------------
#
# Configure Hadoop
#

mkdir -p            $HADOOP_PERM_DIR/hdfs
chown hdfs:hdfs     $HADOOP_PERM_DIR/hdfs

# update the ports and directories not handled by mustache_rider
perl -p -i -e 's~/var/log~'$HADOOP_LOG_DIR'~g'          /etc/default/hadoop*    
