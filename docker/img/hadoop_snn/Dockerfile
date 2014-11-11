FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

EXPOSE 50070
EXPOSE 50470
EXPOSE 8020

COPY img/hadoop_base/conf/core-site.xml.mustache   $HADOOP_CONF_DIR/
COPY img/hadoop_base/conf/hdfs-site.xml.mustache   $HADOOP_CONF_DIR/

RUN /etc/my_init.d/50_hadoop_mustache_rider.sh ; \
    colordiff -uw $HADOOP_CONF_DIR/hdfs-site.xml.mustache $HADOOP_CONF_DIR/hdfs-site.xml ; \
    colordiff -uw $HADOOP_CONF_DIR/core-site.xml.mustache $HADOOP_CONF_DIR/core-site.xml ; \
    true

# Install and configure the resource manager daemon
#
COPY img/hadoop_snn/hadoop-setup_snn.sh /build/
RUN         /build/hadoop-setup_snn.sh

COPY img/hadoop_snn/runit/hadoop_snn-runner.sh /etc/sv/hadoop_snn/run
COPY img/hadoop_snn/runit/hadoop_snn-logger.sh /etc/sv/hadoop_snn/log/run
RUN ln -s /etc/sv/hadoop_snn /etc/service/hadoop_snn
