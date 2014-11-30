#!/bin/bash
set -e ; set -x

# listing space-separated roles in the `$HADOOP_IAMA` environment variable
# nominate this container itself into that role.
#
# Example:
#    HADOOP_IAMA="RM NN"
#    # sets HADOOP_NN_HOSTNAME and HADOOP_RM_HOSTNAME to the output of running `hostname`
#
for iama in $HADOOP_IAMA SELF ; do
  export "HADOOP_${iama}_HOSTNAME=$(hostname)"
done 

# Dump the current env var set
echo "Environment variables associated with HADOOP|TCP|UDP|PORT|ADDR|DIR:"
env | egrep 'HADOOP|TCP|UDP|PORT|ADDR|DIR' || true

#
# This will be run by the my_init process at container startup
#
# It uses config variables specified in Dockerfiles and delivered by container
# linking (https://docs.docker.com/userguide/dockerlinks/#environment-variables)
# to template eg. {{NN_PORT_50070_TCP_ADDR}} into '172.17.0.204'
# dynamically
#

for file in $HADOOP_CONF_DIR/*.xml $HUE_CONF_DIR/hue.ini ; do
  dest_file=$file
  mush_file=$file.mustache
  if [[ -f "$mush_file" ]] ; then
    echo "Taking $mush_file for a mustache ride!"
    cat $mush_file | mush > $dest_file
    colordiff -uw $mush_file $dest_file || true
  fi
done

#
# We shouldn't be doing this here.
#

mkdir -p  $HADOOP_LOG_DIR/hadoop-hdfs  $HADOOP_LOG_DIR/hadoop-mapreduce  $HADOOP_LOG_DIR/hadoop-yarn
chmod 775 $HADOOP_LOG_DIR/hadoop-hdfs  $HADOOP_LOG_DIR/hadoop-mapreduce 
chown yarn:hadoop  $HADOOP_LOG_DIR/hadoop-yarn
chgrp      hadoop  $HADOOP_LOG_DIR/hadoop-hdfs $HADOOP_LOG_DIR/hadoop-mapreduce

echo "Gave configuration a mustache ride on `date`" >> $HADOOP_CONF_DIR/mustache_rider.log 

