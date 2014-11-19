#!/bin/bash
set -e ; set -x

#
# If you choose to mount a container underneath these, the permissions will be wrong.
# So we have to fix that at boot time.
#
# We are purposefully *not* making the directories. These commands will fail if
# they are missing, and so the container will fail if they are missing, and that
# is because something has gone terribly wrong if they are missing. They're
# built into the image at birth, or you are welcome to overlay a volume of your
# own.
#
ls -l $HADOOP_BULK_DIR
chown hdfs:hdfs     $HADOOP_BULK_DIR/hdfs
chown mapred:hadoop $HADOOP_BULK_DIR/jobstatus $HADOOP_BULK_DIR/mapred
chmod 775           $HADOOP_BULK_DIR/jobstatus $HADOOP_BULK_DIR/mapred

# Machine must have a $HADOOP_LOG_DIR, but we'll make the log dirs for you
[ -d $HADOOP_LOG_DIR/yarn-containers ] || mkdir $HADOOP_LOG_DIR/yarn-containers
chown yarn:yarn     $HADOOP_LOG_DIR/yarn-containers

mkdir -p            $HADOOP_BULK_DIR/yarn-local
chown yarn:yarn     $HADOOP_BULK_DIR/yarn-local

mkdir -p  $HADOOP_LOG_DIR/hadoop-hdfs  $HADOOP_LOG_DIR/hadoop-mapreduce  $HADOOP_LOG_DIR/hadoop-0.20-mapreduce $HADOOP_LOG_DIR/hadoop-yarn 
chmod 775 $HADOOP_LOG_DIR/hadoop-hdfs  $HADOOP_LOG_DIR/hadoop-mapreduce  $HADOOP_LOG_DIR/hadoop-0.20-mapreduce
chown yarn:hadoop  $HADOOP_LOG_DIR/hadoop-yarn
chgrp      hadoop  $HADOOP_LOG_DIR/hadoop-hdfs $HADOOP_LOG_DIR/hadoop-mapreduce
