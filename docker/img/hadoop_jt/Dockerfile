FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

# Ports
#
# 8021 rpc 50030 http console 9290 thrift
EXPOSE 8021
EXPOSE 50030
EXPOSE 9290

# Install and configure the resourcemanager and historyserver
#
COPY img/hadoop_jt/hadoop-setup_jt.sh /build/
RUN         /build/hadoop-setup_jt.sh

# Config Files
#
COPY img/hadoop_base/conf/core-site.xml.mustache   $HADOOP_CONF_DIR/
COPY img/hadoop_base/conf/hdfs-site.xml.mustache   $HADOOP_CONF_DIR/
COPY img/hadoop_base/conf/yarn-site.xml.mustache   $HADOOP_CONF_DIR/
COPY img/hadoop_base/conf/mapred-site.xml.mustache $HADOOP_CONF_DIR/

# Ensures Hadoop directories are happy and permissioned even if we mount something under them.
COPY img/hadoop_jt/conf/init-hadoop_jt_fixup.sh /etc/my_init.d/30_hadoop_jt_fixup.sh

# Enable the service daemons
#
COPY img/hadoop_jt/runit /etc/sv
#
RUN  ln -s /etc/sv/hadoop_jt   /etc/service/hadoop_jt
