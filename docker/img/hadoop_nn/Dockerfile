FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

EXPOSE 50070
EXPOSE 50470
EXPOSE 8020

COPY img/hadoop_base/conf/core-site.xml.mustache   $HADOOP_CONF_DIR/
COPY img/hadoop_base/conf/hdfs-site.xml.mustache   $HADOOP_CONF_DIR/

# Dummy these in because docker won't provide them for nn itself
ENV NN_PORT_8020_TCP_ADDR nn
ENV NN_PORT_8020_TCP_PORT 8020

RUN /etc/my_init.d/50_hadoop_mustache_rider.sh ; \
    colordiff -uw $HADOOP_CONF_DIR/hdfs-site.xml.mustache $HADOOP_CONF_DIR/hdfs-site.xml ; \
    colordiff -uw $HADOOP_CONF_DIR/core-site.xml.mustache $HADOOP_CONF_DIR/core-site.xml ; \
    true

# Install and configure the namenode daemon
#
COPY img/hadoop_nn/hadoop-setup_nn.sh /build/
RUN         /build/hadoop-setup_nn.sh

# Format the HDFS
#
RUN sudo -u hdfs hdfs namenode -format

COPY img/hadoop_nn/runit/hadoop_nn-runner.sh /etc/sv/hadoop_nn/run
COPY img/hadoop_nn/runit/hadoop_nn-logger.sh /etc/sv/hadoop_nn/log/run
RUN ln -s /etc/sv/hadoop_nn /etc/service/hadoop_nn
