FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

# 
ENV  HUE_CONF_DIR        /etc/hue/conf.cluster
ENV  HUE_HOME            /usr/lib/hue
ENV  HUE_DATA_DIR        /bulk/hadoop/hue

# Config files for my_init/mustache_rider.sh to prepare
# 
COPY img/hadoop_hue/conf/hue.ini.mustache $HUE_CONF_DIR/

# Install and configure Hue.
#
COPY img/hadoop_hue/hadoop-setup_hue.sh  /build/
RUN             /build/hadoop-setup_hue.sh

# Copy the hue config scripts and enable the servise
#
COPY img/hadoop_hue/runit /etc/sv
RUN  ln -s /etc/sv/hadoop_hue /etc/service/hadoop_hue
