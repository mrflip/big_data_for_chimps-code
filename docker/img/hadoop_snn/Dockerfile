FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

# Ports
#
EXPOSE 50090
EXPOSE 50490

COPY img/hadoop_snn/hadoop-setup_snn.sh /build/

# Install and configure the secondarynamenode
#
RUN          /build/hadoop-setup_snn.sh

# Ensures Hadoop directories are happy and permissioned even if we mount something under them.
#
COPY img/hadoop_snn/conf/init-hadoop_snn_fixup.sh /etc/my_init.d/30_hadoop_snn_fixup.sh

# Enable the service daemons
#
COPY img/hadoop_snn/runit   /etc/sv
RUN ln -s /etc/sv/hadoop_snn /etc/service/hadoop_snn
