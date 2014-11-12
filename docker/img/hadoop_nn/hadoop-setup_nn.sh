#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Namenode
#

# Install, forcing use of the specific common version
$safe_apt_install -t $HADOOP_APT_VERSION hadoop-hdfs-namenode

# Directories
#
mkdir -p            $HADOOP_BULK_DIR/hdfs      $HADOOP_BULK_DIR/name  
chown hdfs:hdfs     $HADOOP_BULK_DIR/hdfs      $HADOOP_BULK_DIR/name  

# update the ports and directories not handled by mustache_rider
perl -p -i -e 's~/var/log~'$HADOOP_LOG_DIR'~g'          /etc/default/hadoop*    
