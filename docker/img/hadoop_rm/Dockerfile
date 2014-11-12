FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

# Ports
#
EXPOSE 50070
EXPOSE 50470
EXPOSE 8020

# Install and configure the resourcemanager
#
COPY img/hadoop_rm/hadoop-setup_rm.sh /build/
RUN         /build/hadoop-setup_rm.sh

# Config Files
#
COPY img/hadoop_base/conf/core-site.xml.mustache   $HADOOP_CONF_DIR/
COPY img/hadoop_base/conf/hdfs-site.xml.mustache   $HADOOP_CONF_DIR/
COPY img/hadoop_base/conf/yarn-site.xml.mustache   $HADOOP_CONF_DIR/
COPY img/hadoop_base/conf/mapred-site.xml.mustache $HADOOP_CONF_DIR/

# Ensures Hadoop directories are happy and permissioned even if we mount something under them.
COPY img/hadoop_rm/conf/init-hadoop_rm_fixup.sh /etc/my_init.d/30_hadoop_rm_fixup.sh

# Enable the service daemons
#
COPY img/hadoop_rm/runit/hadoop_rm-runner.sh   /etc/sv/hadoop_rm/run
COPY img/hadoop_rm/runit/hadoop_rm-logger.sh   /etc/sv/hadoop_rm/log/run
COPY img/hadoop_rm/runit/hadoop_hist-runner.sh /etc/sv/hadoop_hist/run
COPY img/hadoop_rm/runit/hadoop_hist-logger.sh /etc/sv/hadoop_hist/log/run
#
RUN  ln -s /etc/sv/hadoop_rm   /etc/service/hadoop_rm
RUN  ln -s /etc/sv/hadoop_hist /etc/service/hadoop_hist
