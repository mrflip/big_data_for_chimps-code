FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

ENV PIG_VERSION 0.14
ENV PIG_HOME    /usr/local/pig

COPY img/hadoop_lounge/hadoop-setup_client.sh  \
     img/hadoop_lounge/hadoop-setup_pig.sh     \
     img/hadoop_lounge/hadoop-setup_datafu.sh  \
     /build/

# Configure Hadoop client
#
RUN             /build/hadoop-setup_client.sh

# Local build of Pig
#
RUN             /build/hadoop-setup_pig.sh

# Local build of Datafu
#
RUN             /build/hadoop-setup_datafu.sh

COPY img/hadoop_lounge/conf/pig/* $PIG_HOME/conf/

RUN \
  mkdir -p /data/out /data/gold /data/work /data/ripd && \
  chown -R chimpy:admin /data/ && \
  chmod -R ug+rw        /data/ && \
  ls -l    /data/

# ENV  LIPSTICK_DIR           /usr/local/lipstick
# ENV  LIPSTICK_CONSOLE_LIBS  $LIPSTICK_DIR/lipstick-console/build/libs
# COPY img/hadoop_lounge/hadoop-setup_lipstick.sh  /build/
# RUN             /build/hadoop-setup_lipstick.sh
