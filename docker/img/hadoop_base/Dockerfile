FROM       bd4c/baseimage
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

#
# Environment
#

ENV HADOOP_APT_VERSION precise-cdh5.3.0

# Centralize the interesting directories so their lifecycle can be tracked
# separately from the machine image by mounting volumes
ENV HADOOP_BULK_DIR  /bulk/hadoop

# Specific directories for hadoop and zookeeper
ENV HADOOP_TMP_DIR   $HADOOP_BULK_DIR/tmp
ENV HADOOP_LOG_DIR   $HADOOP_BULK_DIR/log

ENV HADOOP_NN_HOSTNAME nn
ENV HADOOP_RM_HOSTNAME rm
ENV HADOOP_JT_HOSTNAME jt

# Hadoop config stored here, and linked as the standard /etc/hadoop/conf
ENV HADOOP_CONF_DIR /etc/hadoop/conf.cluster

COPY img/hadoop_base/hadoop-add_users.sh    \
     img/hadoop_lounge/add_chimpy_user.sh   \
     img/hadoop_base/hadoop-setup_common.sh /build/

# ---------------------------------------------------------------------------
#
# Install
#

# Construct the hadoop users
RUN           /build/hadoop-add_users.sh

# Add the chimpy user
RUN           /build/add_chimpy_user.sh
COPY img/hadoop_lounge/conf/bashrc          /home/chimpy/.bashrc
COPY img/hadoop_lounge/conf/README.md       /home/chimpy/

# Install and configure Hadoop & Zookeeper components common to all images
RUN           /build/hadoop-setup_common.sh

# Hadoop's config files
COPY img/hadoop_base/conf/*.xml.mustache   $HADOOP_CONF_DIR/

# Update configs on each container start
COPY img/hadoop_base/conf/mustache_rider.sh  /etc/my_init.d/50_hadoop_mustache_rider.sh

RUN \
  /etc/my_init.d/50_hadoop_mustache_rider.sh && \
  ls -lR $HADOOP_CONF_DIR $HADOOP_LOG_DIR /build
