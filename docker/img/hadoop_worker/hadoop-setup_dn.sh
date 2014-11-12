#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Datanode
#

# Install, forcing use of the specific common version
$safe_apt_install -t $HADOOP_APT_VERSION hadoop-hdfs-datanode

# Directories
#
mkdir -p            $HADOOP_BULK_DIR/hdfs
chown hdfs:hdfs     $HADOOP_BULK_DIR/hdfs

# update the ports and directories not handled by mustache_rider
perl -p -i -e 's~/var/log~'$HADOOP_LOG_DIR'~g'          /etc/default/hadoop*    
