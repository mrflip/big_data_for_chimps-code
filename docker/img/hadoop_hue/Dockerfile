FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

# Ports
#
EXPOSE 10002

# 
ENV  HUE_CONF_DIR        /etc/hue/conf.cluster
ENV  HUE_HOME            /usr/lib/hue
ENV  HUE_DATA_DIR        /bulk/hadoop/hue

COPY img/hadoop_hue/hadoop-setup_hue.sh \
     /build/

# Config files for my_init/mustache_rider.sh to prepare
# 
COPY img/hadoop_hue/conf/hue.ini.mustache $HUE_CONF_DIR/

# Install and configure Hue.
#
RUN             /build/hadoop-setup_hue.sh

# Copy the hue config scripts and enable the servise
#
COPY img/hadoop_hue/runit /etc/sv
RUN  ln -s /etc/sv/hadoop_hue /etc/service/hadoop_hue
