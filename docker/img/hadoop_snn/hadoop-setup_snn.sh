#!/bin/sh
set -e ; set -x

# ---------------------------------------------------------------------------
#
# Secondarynamenode
#

# Install, forcing use of the specific common version
$safe_apt_install -t $HADOOP_APT_VERSION hadoop-hdfs-secondarynamenode

# Directories
#
mkdir -p            $HADOOP_BULK_DIR/snn
chown hdfs:hdfs     $HADOOP_BULK_DIR/snn

# update the ports and directories not handled by mustache_rider
perl -p -i -e 's~/var/log~'$HADOOP_LOG_DIR'~g'          /etc/default/hadoop*    
