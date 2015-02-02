FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

# Ports
#
# are you ready to see a really long list of ports?
# datanode: console http 50075 ; ipc 50020 ; xceiver 50010; jmx 8010
EXPOSE 50075
EXPOSE 50020
EXPOSE 50010
# nodemgr:  localizer 8040 ; ipc 8041  ; console http 8042
EXPOSE 8040
EXPOSE 8041
EXPOSE 8042
# # tasktracker: 50060 console
# EXPOSE 50060

COPY img/hadoop_worker/hadoop-setup_dn.sh \
     img/hadoop_worker/hadoop-setup_nm.sh \
     img/hadoop_worker/hadoop-setup_tt.sh \
     /build/

# Install and configure the datanode
#
RUN             /build/hadoop-setup_dn.sh

# Install and configure the nodemanager
#
RUN             /build/hadoop-setup_nm.sh

# # Alternatively: Install and configure the tasktracker
# #
# RUN             /build/hadoop-setup_tt.sh

# Ensures Hadoop directories are happy and permissioned even if we mount something under them.
COPY img/hadoop_worker/conf/init-hadoop_worker_fixup.sh /etc/my_init.d/30_hadoop_worker_fixup.sh

# Enable the service daemons
#
COPY img/hadoop_worker/runit /etc/sv
#
RUN  \
  ln -s /etc/sv/hadoop_dn /etc/service/hadoop_dn && \
  ln -s /etc/sv/hadoop_nm /etc/service/hadoop_nm
  # ln -s /etc/sv/hadoop_tt /etc/service/hadoop_tt

