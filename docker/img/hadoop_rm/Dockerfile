FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

EXPOSE 50070
EXPOSE 50470
EXPOSE 8020

COPY img/hadoop_base/conf/core-site.xml.mustache   $HADOOP_CONF_DIR/
COPY img/hadoop_base/conf/yarn-site.xml.mustache   $HADOOP_CONF_DIR/

RUN /etc/my_init.d/50_hadoop_mustache_rider.sh ; \
    colordiff -uw $HADOOP_CONF_DIR/core-site.xml.mustache $HADOOP_CONF_DIR/core-site.xml ; \
    colordiff -uw $HADOOP_CONF_DIR/yarn-site.xml.mustache $HADOOP_CONF_DIR/yarn-site.xml ; \
    true

# Install and configure the resource manager daemon
#
COPY img/hadoop_rm/hadoop-setup_rm.sh /build/
RUN         /build/hadoop-setup_rm.sh

# Install and enable the resource manager daemon
#
COPY img/hadoop_rm/runit/hadoop_rm-runner.sh   /etc/sv/hadoop_rm/run
COPY img/hadoop_rm/runit/hadoop_rm-logger.sh   /etc/sv/hadoop_rm/log/run
COPY img/hadoop_rm/runit/hadoop_hist-runner.sh /etc/sv/hadoop_hist/run
COPY img/hadoop_rm/runit/hadoop_hist-logger.sh /etc/sv/hadoop_hist/log/run
RUN  ln -s /etc/sv/hadoop_rm   /etc/service/hadoop_rm 
# RUN  ln -s /etc/sv/hadoop_hist /etc/service/hadoop_hist
