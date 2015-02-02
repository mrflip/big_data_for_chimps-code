FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

# Ports
#
# rsrc mgr: console http 8088 / https 8090; scheduler 8030;
#           tracker 8031; ipc 8032; admin 8033; ganglia 8660, shuffle 13562;
# history:  console 19888 / https 19890, ipc 10020, admin 1033
EXPOSE 8088
EXPOSE 8030
EXPOSE 8031
EXPOSE 8032
EXPOSE 8033
EXPOSE 13562
EXPOSE 19888
EXPOSE 10020
EXPOSE 1033

COPY img/hadoop_rm/hadoop-setup_rm.sh \
     /build/

# Install and configure the resourcemanager and historyserver
#
RUN         /build/hadoop-setup_rm.sh

# Ensures Hadoop directories are happy and permissioned even if we mount something under them.
COPY img/hadoop_rm/conf/init-hadoop_rm_fixup.sh /etc/my_init.d/30_hadoop_rm_fixup.sh

# Enable the service daemons
#
COPY img/hadoop_rm/runit /etc/sv
#
RUN  \
  ln -s /etc/sv/hadoop_rm   /etc/service/hadoop_rm   && \
  ln -s /etc/sv/hadoop_hist /etc/service/hadoop_hist
