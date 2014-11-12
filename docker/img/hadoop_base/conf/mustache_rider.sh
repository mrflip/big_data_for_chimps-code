#!/bin/bash
set -e ; set -x

#
# This will be run by the my_init process at container startup
#
# It uses config variables specified in Dockerfiles and delivered by container
# linking (https://docs.docker.com/userguide/dockerlinks/#environment-variables)
# to template eg. {{NN_PORT_50070_TCP_ADDR}} into '172.17.0.204'
# dynamically
#

for file in core-site.xml mapred-site.xml yarn-site.xml hdfs-site.xml ; do
  dest_file=$HADOOP_CONF_DIR/$file
  mush_file=$HADOOP_CONF_DIR/$file.mustache
  if [[ -f "$mush_file" ]] ; then
    cat $mush_file | mush > $dest_file
  fi
done

mkdir -p  $HADOOP_LOG_DIR/hadoop-hdfs  $HADOOP_LOG_DIR/hadoop-mapreduce  $HADOOP_LOG_DIR/hadoop-yarn
chmod 775 $HADOOP_LOG_DIR/hadoop-hdfs  $HADOOP_LOG_DIR/hadoop-mapreduce 
chown yarn:hadoop  $HADOOP_LOG_DIR/hadoop-yarn
chgrp      hadoop  $HADOOP_LOG_DIR/hadoop-hdfs $HADOOP_LOG_DIR/hadoop-mapreduce

echo "Gave configuration a mustache ride on `date`" >> $HADOOP_CONF_DIR/mustache_rider.log 

