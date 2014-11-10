FROM bd4c/baseimage
MAINTAINER Flip Kromer <flip@infochimps.com>
MAINTAINER Russell Jurney
WORKDIR /root

#
# Directories
#

# Centralize the interesting directories so their lifecycle can be tracked
# separately from the machine image. In a production setting these would
# correspond to distinct volumes with different durability/speed/etc tradeoffs

ENV     BULK_DIR /bulk

# Directory where durable data -- HDFS, databases, etc -- should live
ENV     PERM_DIR /bulk/perm
# Directory for local ephemeral-ish data -- fast scratch space for transaction journals
ENV     LOCL_DIR /bulk/locl
# Directory for logs
ENV     LOG_DIR  /bulk/log

# Specific directories for hadoop and zookeeper
ENV     HADOOP_PERM_DIR  $PERM_DIR/hadoop
ENV     HADOOP_LOCL_DIR  $LOCL_DIR/hadoop
ENV     HADOOP_TMP_DIR   $LOCL_DIR/hadoop/tmp
ENV     HADOOP_LOG_DIR   $LOG_DIR/hadoop
ENV     ZK_PERM_DIR      $PERM_DIR/zookeeper/db
ENV     ZK_LOCL_DIR      $LOCL_DIR/zookeeper/txlog
ENV     ZK_LOG_DIR       $LOG_DIR/zookeeper

# Hadoop config stored here, and linked as the standard /etc/hadoop/conf
ENV HADOOP_CONF /etc/hadoop/conf.pseudo

# ---------------------------------------------------------------------------
#
# Install
#

# Construct the hadoop users
COPY img/hadoop_base/build/hadoop-add_users.sh /build/hadoop-add_users.sh
RUN  /build/hadoop-add_users.sh

# Install and configure Hadoop & Zookeeper components common to all images
COPY img/hadoop_base/build/hadoop-setup_common.sh /build/hadoop-setup_common.sh
RUN  /build/hadoop-setup_common.sh

COPY core-site.xml   $HADOOP_CONF/core-site.xml
