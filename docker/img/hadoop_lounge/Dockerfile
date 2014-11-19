FROM       bd4c/hadoop_base
MAINTAINER Flip Kromer <flip@infochimps.com>, Russell Jurney

# 
ENV  HADOOP_EXAMPLES_JAR /usr/lib/hadoop-mapreduce/hadoop-mapreduce-examples.jar
ENV  HUE_CONF_DIR        /etc/hue/conf.cluster
ENV  HUE_HOME            /usr/lib/hue
ENV  HUE_DATA_DIR        /bulk/hadoop/hue
ENV  HADOOP_HIVE_HOSTNAME lounge

# Configure Hadoop client
#
COPY img/hadoop_lounge/hadoop-setup_client.sh  /build/
RUN             /build/hadoop-setup_client.sh

# Config files for my_init/mustache_rider.sh to prepare
# 
COPY img/hadoop_lounge/conf/hue.ini.mustache $HUE_CONF_DIR/

# Install and configure Hue.
#
COPY img/hadoop_lounge/hadoop-setup_hue.sh  /build/
RUN             /build/hadoop-setup_hue.sh

RUN $safe_apt_install ant maven2

# ENV PIG_VERSION 0.13
# ENV PIG_HOME    /usr/local/pig
# 
# COPY img/hadoop_lounge/hadoop-setup_pig.sh  /build/
# RUN             /build/hadoop-setup_pig.sh
# 
# ENV  LIPSTICK_DIR           /usr/local/lipstick
# ENV  LIPSTICK_CONSOLE_LIBS  $LIPSTICK_DIR/lipstick-console/build/libs
# 
# COPY img/hadoop_lounge/hadoop-setup_pig.sh  /build/
# RUN             /build/hadoop-setup_pig.sh
# 
# RUN \
#   mvn org.apache.maven.plugins:maven-install-plugin:2.5:install-file \
#     -Dfile=build/pig-0.13.1-SNAPSHOT.jar \
#     -DgroupId=org.apache.pig \
#     -DartifactId=pig \
#     -Dversion=0.13.0-h2 \
#     -Dpackaging=jar
# 
# 
# # That, but for hadoop    
# RUN \
#   false && \
#   mvn org.apache.maven.plugins:maven-install-plugin:2.5:install-file \
#     -Dfile=build/pig-0.13.1-SNAPSHOT.jar \
#     -DgroupId=org.apache.pig \
#     -DartifactId=pig \
#     -Dversion=0.13.0-h2 \
#     -Dpackaging=jar


# Copy the hue config scripts and enable the servise
#
COPY img/hadoop_lounge/runit/hadoop_hue-runner.sh /etc/sv/hadoop_hue/run
COPY img/hadoop_lounge/runit/hadoop_hue-logger.sh /etc/sv/hadoop_hue/log/run
#
RUN  ln -s /etc/sv/hadoop_hue /etc/service/hadoop_hue
#

# ENTRYPOINT ["/usr/bin/runsvdir", "-P", "/etc/service"]
