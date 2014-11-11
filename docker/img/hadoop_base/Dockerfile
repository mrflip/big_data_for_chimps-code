FROM bd4c/baseimage
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

#
# Environment
#

ENV     HADOOP_APT_VERSION precise-cdh5.2.0

# Centralize the interesting directories so their lifecycle can be tracked
# separately from the machine image. In a production setting these would
# correspond to distinct volumes with different durability/speed/etc tradeoffs
ENV     BULK_DIR         /bulk 
# Directory where durable data -- HDFS, databases, etc -- should live
ENV     PERM_DIR         /bulk/perm
# Directory for local ephemeral-ish data -- fast scratch space for transaction journals
ENV     LOCL_DIR         /bulk/locl
# Directory for logs
ENV     LOG_DIR          /bulk/log

# Specific directories for hadoop and zookeeper
ENV     HADOOP_PERM_DIR  $PERM_DIR/hadoop
ENV     HADOOP_LOCL_DIR  $LOCL_DIR/hadoop
ENV     HADOOP_TMP_DIR   $LOCL_DIR/hadoop/tmp
ENV     HADOOP_LOG_DIR   $LOG_DIR/hadoop
ENV     ZK_PERM_DIR      $PERM_DIR/zookeeper/db
ENV     ZK_LOCL_DIR      $LOCL_DIR/zookeeper/txlog
ENV     ZK_LOG_DIR       $LOG_DIR/zookeeper

# Hadoop config stored here, and linked as the standard /etc/hadoop/conf
ENV HADOOP_CONF_DIR /etc/hadoop/conf.cluster

# ---------------------------------------------------------------------------
#
# Install
#

# Construct the hadoop users
COPY img/hadoop_base/hadoop-add_users.sh    /build/
RUN           /build/hadoop-add_users.sh

# Install and configure Hadoop & Zookeeper components common to all images
COPY img/hadoop_base/hadoop-setup_common.sh /build/
RUN           /build/hadoop-setup_common.sh

COPY img/hadoop_base/conf/core-site.xml.mustache  $HADOOP_CONF_DIR/

# Update configs on each container start
COPY img/hadoop_base/conf/mustache_rider.sh  /etc/my_init.d/50_hadoop_mustache_rider.sh

RUN /etc/my_init.d/50_hadoop_mustache_rider.sh
RUN colordiff -uw $HADOOP_CONF_DIR/core-site.xml.mustache $HADOOP_CONF_DIR/core-site.xml ; true
