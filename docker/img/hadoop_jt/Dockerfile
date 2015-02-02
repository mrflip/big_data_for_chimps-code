FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

# Ports
#
# 8021 rpc 50030 http console 9290 thrift
EXPOSE 8021
EXPOSE 50030
EXPOSE 9290

COPY img/hadoop_jt/hadoop-setup_jt.sh \
     /build/

# Install and configure the resourcemanager and historyserver
#
RUN         /build/hadoop-setup_jt.sh

# Ensures Hadoop directories are happy and permissioned even if we mount something under them.
COPY img/hadoop_jt/conf/init-hadoop_jt_fixup.sh /etc/my_init.d/30_hadoop_jt_fixup.sh

# Enable the service daemons
#
COPY img/hadoop_jt/runit /etc/sv
#
RUN  ln -s /etc/sv/hadoop_jt   /etc/service/hadoop_jt
