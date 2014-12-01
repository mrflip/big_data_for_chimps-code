FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

ENV PIG_VERSION 0.13
ENV PIG_HOME    /usr/local/pig

# Configure Hadoop client
#
COPY img/hadoop_lounge/hadoop-setup_client.sh  /build/
RUN             /build/hadoop-setup_client.sh

COPY img/hadoop_lounge/hadoop-setup_pig.sh  /build/
RUN             /build/hadoop-setup_pig.sh

# ENV  LIPSTICK_DIR           /usr/local/lipstick
# ENV  LIPSTICK_CONSOLE_LIBS  $LIPSTICK_DIR/lipstick-console/build/libs
# 
# COPY img/hadoop_lounge/hadoop-setup_lipstick.sh  /build/
# RUN             /build/hadoop-setup_lipstick.sh
