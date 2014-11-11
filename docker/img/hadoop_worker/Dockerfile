FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

# are you ready to see a really long list of ports?
# datanode: console http 50075 / https 50475; ipc 50020 ; xceiver 50010; jmx 8010
# nodemgr:  console http 8042  / https 8044;  ipc 8041  ; localizer 8040
EXPOSE 50075
EXPOSE 50475
EXPOSE 50020
EXPOSE 50010
EXPOSE 8010
EXPOSE 8042
EXPOSE 8044
EXPOSE 8040
EXPOSE 8041

COPY img/hadoop_base/conf/core-site.xml.mustache   $HADOOP_CONF_DIR/
COPY img/hadoop_base/conf/hdfs-site.xml.mustache   $HADOOP_CONF_DIR/

RUN /etc/my_init.d/50_hadoop_mustache_rider.sh ; \
    colordiff -uw $HADOOP_CONF_DIR/hdfs-site.xml.mustache $HADOOP_CONF_DIR/hdfs-site.xml ; \
    colordiff -uw $HADOOP_CONF_DIR/core-site.xml.mustache $HADOOP_CONF_DIR/core-site.xml ; \
    true

# Install and configure the datanode daemon
#
COPY img/hadoop_worker/hadoop-setup_dn.sh /build/
RUN         /build/hadoop-setup_dn.sh

COPY img/hadoop_worker/runit/hadoop_dn-runner.sh /etc/sv/hadoop_dn/run
COPY img/hadoop_worker/runit/hadoop_dn-logger.sh /etc/sv/hadoop_dn/log/run
# RUN ln -s /etc/sv/hadoop_dn /etc/service/hadoop_dn
