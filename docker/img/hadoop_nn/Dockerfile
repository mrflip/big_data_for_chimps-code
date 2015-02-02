FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

# Ports
#
EXPOSE 50070
EXPOSE 8020

COPY img/hadoop_nn/hadoop-setup_nn.sh       \
     img/hadoop_nn/hadoop-bootstrap_hdfs.sh \
     /build/

# Install and configure the namenode
#
RUN         /build/hadoop-setup_nn.sh

# Ensures Hadoop directories are happy and permissioned even if we mount something under them.
COPY img/hadoop_nn/conf/init-hadoop_nn_fixup.sh /etc/my_init.d/30_hadoop_nn_fixup.sh

# Enable the service daemons
#
COPY img/hadoop_nn/runit /etc/sv
RUN  \
  ls -lR /etc/sv  ; \
  ln -s /etc/sv/hadoop_nn /etc/service/hadoop_nn ; \
  ls -lR /etc/sv /etc/service ; \
  ls -l /etc/hadoop/conf/*.xml*

# Format the HDFS and make initial directories
#
RUN         /build/hadoop-bootstrap_hdfs.sh

